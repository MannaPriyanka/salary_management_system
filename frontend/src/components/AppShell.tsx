import { Link as RouterLink, Outlet, useNavigate } from "react-router";
import AppBar from "@mui/material/AppBar";
import Box from "@mui/material/Box";
import Button from "@mui/material/Button";
import Container from "@mui/material/Container";
import Toolbar from "@mui/material/Toolbar";
import Typography from "@mui/material/Typography";
import { useAuth } from "../auth/AuthContext";

export function AppShell() {
  const { user, signOut } = useAuth();
  const navigate = useNavigate();

  async function handleSignOut() {
    await signOut();
    navigate("/sign-in", { replace: true });
  }

  return (
    <Box sx={{ minHeight: "100vh", bgcolor: "background.default" }}>
      <AppBar position="static">
        <Toolbar sx={{ gap: 2, flexWrap: "wrap" }}>
          <Typography variant="h6" component="h1" sx={{ flexGrow: 1 }}>
            ACME Salary Management
          </Typography>
          <Button color="inherit" component={RouterLink} to="/employees">
            Employees
          </Button>
          <Button color="inherit" component={RouterLink} to="/statistics">
            Pay statistics
          </Button>
          <Typography variant="body2" sx={{ opacity: 0.85 }}>
            {user?.email}
          </Typography>
          <Button color="inherit" onClick={handleSignOut}>
            Sign out
          </Button>
        </Toolbar>
      </AppBar>
      <Container maxWidth="lg" sx={{ py: 4 }}>
        <Outlet />
      </Container>
    </Box>
  );
}
