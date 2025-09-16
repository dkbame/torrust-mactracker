// Custom commands for user context

// Registration

Cypress.Commands.add("register", (registration_form) => {
  cy.visit("/signup");

  cy.get("input[data-cy=\"registration-form-username\"]").type(registration_form.username);
  cy.get("input[data-cy=\"registration-form-email\"]").type(registration_form.email);
  cy.get("input[data-cy=\"registration-form-password\"]").type(registration_form.password);
  cy.get("input[data-cy=\"registration-form-confirm-password\"]").type(registration_form.confirm_password);

  cy.get("button[data-cy=\"registration-form-submit\"]").click();

  cy.contains("Your account was registered!");
});

Cypress.Commands.add("register_as_admin", (registration_form) => {
  cy.register(registration_form);

  cy.task("grantAdminRole", { username: registration_form.username });
});

Cypress.Commands.add("delete_user_from_database", (username) => {
  cy.task("deleteUser", { username });
});

// Authentication

Cypress.Commands.add("login", (username: string, password: string) => {
  cy.visit("/signin");

  cy.get("input[data-cy=\"login-form-username\"]").type(username);
  cy.get("input[data-cy=\"login-form-password\"]").type(password);

  cy.get("button[data-cy=\"login-form-submit\"]").click();

  cy.url().should("include", "/torrents");
});

Cypress.Commands.add("logout", () => {
  cy.get("a[data-cy=\"logout-link\"]").click();
});

// Others

Cypress.Commands.add("register_and_login", (registration_form) => {
  cy.visit("/");
  cy.visit("/signup");
  cy.register(registration_form);
  cy.login(registration_form.username, registration_form.password);
});

Cypress.Commands.add("register_as_admin_and_login", (registration_form) => {
  cy.visit("/");
  cy.visit("/signup");
  cy.register_as_admin(registration_form);
  cy.login(registration_form.username, registration_form.password);
});
