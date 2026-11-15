import { createBrowserRouter, RouterProvider, Navigate } from "react-router";
import { AuthProvider } from "./auth/AuthContext";
import { AppShell } from "./components/AppShell";
import { RequireAuth } from "./components/RequireAuth";
import { EmployeeDetailPage } from "./pages/EmployeeDetailPage";
import { EmployeeFormPage } from "./pages/EmployeeFormPage";
import { EmployeesPage } from "./pages/EmployeesPage";
import { HomePage } from "./pages/HomePage";
import { SignInPage } from "./pages/SignInPage";

export const router = createBrowserRouter([
  { path: "/sign-in", element: <SignInPage /> },
  {
    path: "/",
    element: (
      <RequireAuth>
        <AppShell />
      </RequireAuth>
    ),
    children: [
      { index: true, element: <HomePage /> },
      { path: "employees", element: <EmployeesPage /> },
      { path: "employees/new", element: <EmployeeFormPage /> },
      { path: "employees/:id", element: <EmployeeDetailPage /> },
      { path: "employees/:id/edit", element: <EmployeeFormPage /> },
      { path: "statistics", element: <HomePage /> },
      { path: "*", element: <Navigate to="/" replace /> },
    ],
  },
]);

export function App() {
  return (
    <AuthProvider>
      <RouterProvider router={router} />
    </AuthProvider>
  );
}
