# Deterministic synthetic data for the assessment: departments, designations, countries,
# employees, and salary histories in four currencies (INR, USD, EUR, GBP).
#
# Explicit only: nothing runs it on startup or deploy. Repeatable: one seeded random source
# drives every value, and inserts skip rows that already exist. Needs an HR Manager account,
# which is recorded as the author of each seeded revision.
class SyntheticSeed
  class Error < StandardError; end

  DEFAULT_EMPLOYEE_COUNT = 10_000
  DEFAULT_SEED = 20_261_115
  BATCH_SIZE = 1_000

  DEPARTMENTS = %w[Engineering Finance Human\ Resources Sales Operations Marketing Legal Customer\ Support].freeze
  DESIGNATIONS = [ "Associate", "Analyst", "Specialist", "Engineer", "Senior Engineer", "Lead Engineer",
                  "Manager", "Senior Manager", "Director", "Vice President" ].freeze
  # country code, name, currency, share of employees in percent (cumulative), base salary range
  COUNTRIES = [
    [ "IN", "India", "INR", 40, 600_000..3_600_000 ],
    [ "US", "United States", "USD", 65, 60_000..220_000 ],
    [ "DE", "Germany", "EUR", 85, 45_000..150_000 ],
    [ "GB", "United Kingdom", "GBP", 100, 35_000..120_000 ]
  ].freeze
  JOINING_RANGE = Date.new(2010, 1, 1)..Date.new(2024, 6, 30)
  EXIT_CAP = Date.new(2026, 6, 30)

  def self.call(employee_count: DEFAULT_EMPLOYEE_COUNT, seed: DEFAULT_SEED)
    new(employee_count: employee_count, seed: seed).call
  end

  def initialize(employee_count:, seed:)
    @employee_count = employee_count
    @seed = seed
  end

  def call
    author = User.order(:id).first or raise Error, "Create the HR Manager account first (accounts:bootstrap_hr_manager)."

    rng = Random.new(@seed)
    Faker::Config.random = rng
    departments = ensure_lookup(Department, DEPARTMENTS)
    designations = ensure_lookup(Designation, DESIGNATIONS)
    countries = ensure_countries
    ensure_currencies

    employee_rows = []
    revision_rows = []
    @employee_count.times do |index|
      number = index + 1
      employee, revisions = build_employee(rng, number, departments, designations, countries)
      employee_rows << employee
      revision_rows.concat(revisions)
    end

    insert_employees(employee_rows)
    insert_revisions(revision_rows, author)

    { employees: Employee.count, salary_revisions: SalaryRevision.count, currencies: SalaryRevision.distinct.count(:currency_code) }
  end

  private

  def ensure_lookup(model, names)
    names.each { |name| model.find_or_create_by!(name: name) { |row| row.active = true } }
    # Sorted by name so the same seed always picks the same rows, whatever the database order.
    model.where(name: names).order(:name).pluck(:name, :id).to_h
  end

  def ensure_countries
    COUNTRIES.each_with_object({}) do |(code, name, _currency, _share, _range), map|
      country = Country.find_or_create_by!(code: code) { |row| row.name = name; row.active = true }
      map[code] = country.id
    end
  end

  def ensure_currencies
    COUNTRIES.each do |_code, _name, currency, _share, _range|
      Currency.find_or_create_by!(code: currency) do |row|
        row.name = currency
        row.minor_units = 2
        row.enabled = true
      end
    end
  end

  def build_employee(rng, number, departments, designations, countries)
    first = Faker::Name.first_name
    last = Faker::Name.last_name
    code = format("EMP%05d", number)
    country = pick_country(rng)
    joining = JOINING_RANGE.begin + rng.rand((JOINING_RANGE.end - JOINING_RANGE.begin).to_i)
    status, exit_date = employment(rng, joining)
    now = Time.current

    employee = {
      employee_code: code,
      full_name: "#{first} #{last}",
      work_email: "#{local_part(first, last)}.#{number}@example.test",
      department_id: departments.values[rng.rand(departments.size)],
      designation_id: designations.values[rng.rand(designations.size)],
      country_id: countries.fetch(country[0]),
      employment_status: status,
      joining_date: joining,
      exit_date: exit_date,
      created_at: now,
      updated_at: now
    }

    [ employee, revisions_for(rng, code, joining, exit_date, country) ]
  end

  def pick_country(rng)
    roll = rng.rand(100)
    COUNTRIES.find { |country| roll < country[3] }
  end

  def employment(rng, joining)
    roll = rng.rand(100)
    return [ "active", nil ] if roll < 85
    return [ "on_leave", nil ] if roll < 90

    exit_date = [ joining + 400 + rng.rand(600), EXIT_CAP ].min
    [ "exited", exit_date ]
  end

  def revisions_for(rng, code, joining, exit_date, country)
    _code, _name, currency, _share, range = country
    last_day = exit_date || Date.current
    base = range.begin + rng.rand(range.size)
    step = base / 20
    count = 1 + rng.rand(3)

    (0...count).filter_map do |k|
      effective = joining + k * (365 + rng.rand(200))
      next if effective > last_day || effective > Date.current

      {
        employee_code: code,
        currency_code: currency,
        base_amount: "#{base + k * step}.00",
        effective_date: effective,
        reason: k.zero? ? "Initial salary" : "Annual review"
      }
    end
  end

  def local_part(first, last)
    "#{first}.#{last}".downcase.gsub(/[^a-z0-9.]/, "")
  end

  def insert_employees(rows)
    rows.each_slice(BATCH_SIZE) do |batch|
      Employee.insert_all(batch, unique_by: :employee_code)
    end
  end

  def insert_revisions(rows, author)
    ids = Employee.where(employee_code: rows.map { |r| r[:employee_code] }.uniq).pluck(:employee_code, :id).to_h
    now = Time.current
    prepared = rows.map do |row|
      row.except(:employee_code).merge(employee_id: ids.fetch(row[:employee_code]), recorded_by_id: author.id,
                                       created_at: now, updated_at: now)
    end
    prepared.each_slice(BATCH_SIZE) do |batch|
      SalaryRevision.insert_all(batch, unique_by: %i[employee_id effective_date])
    end
  end
end
