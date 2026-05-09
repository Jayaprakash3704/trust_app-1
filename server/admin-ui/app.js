import { initializeApp } from "https://www.gstatic.com/firebasejs/10.12.5/firebase-app.js";
import {
  getAuth,
  onAuthStateChanged,
  sendPasswordResetEmail,
  signInWithEmailAndPassword,
  signOut,
} from "https://www.gstatic.com/firebasejs/10.12.5/firebase-auth.js";

const firebaseConfig = {
  apiKey: "AIzaSyD64MhT8jlDavZ-t2k3KaU92EZn2z7NPD8",
  authDomain: "trust-app-a2a0e.firebaseapp.com",
  projectId: "trust-app-a2a0e",
  appId: "1:469636089136:web:50fdc76483f6395a9034f5",
  messagingSenderId: "469636089136",
  storageBucket: "trust-app-a2a0e.firebasestorage.app",
  measurementId: "G-C2MW19P965",
};

const API_BASE = "/admin";
const PAYMENT_BASE = "/payment";

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);

const ui = {
  envLabel: document.getElementById("envLabel"),
  apiBase: document.getElementById("apiBase"),
  accessIndicator: document.getElementById("accessIndicator"),
  accessLabel: document.getElementById("accessLabel"),
  accessBadge: document.getElementById("accessBadge"),
  sessionState: document.getElementById("sessionState"),
  sessionEmail: document.getElementById("sessionEmail"),
  sessionUid: document.getElementById("sessionUid"),
  sessionRole: document.getElementById("sessionRole"),
  sessionNote: document.getElementById("sessionNote"),
  healthForm: document.getElementById("healthForm"),
  rootStatusButton: document.getElementById("rootStatusButton"),
  healthOutput: document.getElementById("healthOutput"),
  authForm: document.getElementById("authForm"),
  authEmail: document.getElementById("authEmail"),
  authPassword: document.getElementById("authPassword"),
  signOutButton: document.getElementById("signOutButton"),
  authMessage: document.getElementById("authMessage"),
  createOrderForm: document.getElementById("createOrderForm"),
  verifyPaymentForm: document.getElementById("verifyPaymentForm"),
  paymentFailedForm: document.getElementById("paymentFailedForm"),
  createUserForm: document.getElementById("createUserForm"),
  updateUserForm: document.getElementById("updateUserForm"),
  resetLinkForm: document.getElementById("resetLinkForm"),
  resetEmail: document.getElementById("resetEmail"),
  sendResetEmailButton: document.getElementById("sendResetEmailButton"),
  createOrderOutput: document.getElementById("createOrderOutput"),
  verifyPaymentOutput: document.getElementById("verifyPaymentOutput"),
  paymentFailedOutput: document.getElementById("paymentFailedOutput"),
  createUserOutput: document.getElementById("createUserOutput"),
  updateUserOutput: document.getElementById("updateUserOutput"),
  resetLinkOutput: document.getElementById("resetLinkOutput"),
  toast: document.getElementById("toast"),
};

const lockCards = Array.from(document.querySelectorAll("[data-lock]"));

const state = {
  user: null,
  isAdmin: false,
  token: null,
};

function setAuthMessage(message, tone = "") {
  ui.authMessage.textContent = message;
  ui.authMessage.classList.remove("error", "success");
  if (tone) {
    ui.authMessage.classList.add(tone);
  }
}

let toastTimer = null;
function showToast(message) {
  ui.toast.textContent = message;
  ui.toast.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => {
    ui.toast.classList.remove("show");
  }, 2800);
}

function getAccessLevel(user, isAdmin) {
  if (!user) {
    return "locked";
  }
  return isAdmin ? "admin" : "user";
}

function resolveAccessLabel(level) {
  if (level === "admin") {
    return "Admin";
  }
  if (level === "user") {
    return "User";
  }
  return "Locked";
}

function setAccessBadge(level) {
  const label = resolveAccessLabel(level);
  ui.accessBadge.textContent = label;
  ui.accessBadge.classList.toggle("admin", level === "admin");
  ui.accessBadge.classList.toggle("user", level === "user");
  ui.accessBadge.classList.toggle("locked", level === "locked");
}

function setAccessIndicator(level) {
  const label = resolveAccessLabel(level);
  ui.accessLabel.textContent = label;
  ui.accessIndicator.classList.remove("locked", "user", "admin");
  ui.accessIndicator.classList.add(level);
  ui.accessIndicator.setAttribute("aria-label", `${label} access`);
}

function setActionLock(level) {
  lockCards.forEach((card) => {
    const lockMode = card.dataset.lock;
    const locked =
      lockMode === "admin"
        ? level !== "admin"
        : lockMode === "auth"
          ? level === "locked"
          : false;

    card.classList.toggle("is-locked", locked);
    card.setAttribute("aria-disabled", locked ? "true" : "false");
    card.querySelectorAll("input, textarea, button").forEach((el) => {
      el.disabled = locked;
    });
  });
}

function setSessionDisplay(user, isAdmin) {
  const level = getAccessLevel(user, isAdmin);
  ui.sessionState.textContent = user ? "Signed in" : "Signed out";
  ui.sessionEmail.textContent = user?.email || "-";
  ui.sessionUid.textContent = user?.uid || "-";
  ui.sessionRole.textContent = user ? (isAdmin ? "admin" : "user") : "-";
  setAccessBadge(level);
  setAccessIndicator(level);
  setActionLock(level);

  if (!user) {
    ui.sessionNote.textContent = "Sign in to unlock user and admin features.";
  } else if (!isAdmin) {
    ui.sessionNote.textContent =
      "Signed in as a user. Admin features remain locked.";
  } else {
    ui.sessionNote.textContent = "Admin access verified.";
  }

  ui.signOutButton.disabled = !user;
  ui.authForm.classList.toggle("hidden", Boolean(user));
}

function resolveOutputText(payload, ok) {
  if (!payload) {
    return ok ? "Done." : "Request failed.";
  }
  if (typeof payload === "string") {
    return payload;
  }
  if (payload.passwordResetLink) {
    return payload.passwordResetLink;
  }
  if (payload.error) {
    return payload.error;
  }
  const keys = Object.keys(payload);
  if (keys.length > 1) {
    return JSON.stringify(payload, null, 2);
  }
  if (payload.status) {
    return payload.status;
  }
  return JSON.stringify(payload, null, 2);
}

function setOutput(el, payload, ok) {
  el.dataset.state = ok ? "success" : "error";
  el.textContent = resolveOutputText(payload, ok);
  if (payload && payload.passwordResetLink) {
    el.dataset.copyValue = payload.passwordResetLink;
  } else {
    delete el.dataset.copyValue;
  }
}

function normalizeAadhaar(value) {
  return value.replace(/\s+/g, "").trim();
}

function normalizePan(value) {
  return value.trim().toUpperCase();
}

async function refreshSession(user) {
  const tokenResult = await user.getIdTokenResult(true);
  state.user = user;
  state.token = tokenResult.token;
  state.isAdmin = tokenResult.claims?.role === "admin";
  setSessionDisplay(user, state.isAdmin);
}

async function getAuthToken() {
  const user = auth.currentUser;
  if (!user) {
    throw new Error("Sign in required.");
  }
  state.token = await user.getIdToken(true);
  return state.token;
}

async function parseResponse(response) {
  const rawText = await response.text();
  if (!rawText) {
    return {};
  }
  try {
    return JSON.parse(rawText);
  } catch (error) {
    return rawText;
  }
}

function resolveErrorMessage(data) {
  if (!data) {
    return "Request failed.";
  }
  if (typeof data === "string" && data.trim()) {
    return data;
  }
  return data.error || "Request failed.";
}

async function callAdmin(endpoint, payload) {
  if (!state.isAdmin) {
    throw new Error("Admin access required.");
  }
  const token = await getAuthToken();
  const response = await fetch(`${API_BASE}${endpoint}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(payload),
  });

  const data = await parseResponse(response);
  if (!response.ok) {
    throw new Error(resolveErrorMessage(data));
  }

  return data;
}

async function callPayment(endpoint, payload) {
  if (!state.user) {
    throw new Error("Sign in required.");
  }
  const token = await getAuthToken();
  const response = await fetch(`${PAYMENT_BASE}${endpoint}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(payload),
  });

  const data = await parseResponse(response);
  if (!response.ok) {
    throw new Error(resolveErrorMessage(data));
  }

  return data;
}

async function callPublic(endpoint) {
  const response = await fetch(endpoint, { method: "GET" });
  const data = await parseResponse(response);
  if (!response.ok) {
    throw new Error(resolveErrorMessage(data));
  }
  return data;
}

function setBusy(form, busy) {
  form.querySelectorAll("button").forEach((button) => {
    button.disabled = busy;
  });
  form.classList.toggle("is-busy", busy);
}

ui.envLabel.textContent = location.hostname || "local";
ui.apiBase.textContent = "/payment + /admin";
setSessionDisplay(null, false);
ui.signOutButton.disabled = true;

onAuthStateChanged(auth, async (user) => {
  if (!user) {
    state.user = null;
    state.isAdmin = false;
    state.token = null;
    setSessionDisplay(null, false);
    return;
  }

  try {
    await refreshSession(user);
    setAuthMessage("Signed in.", "success");
  } catch (error) {
    setAuthMessage("Unable to verify auth claims.", "error");
    setSessionDisplay(user, false);
  }
});

ui.authForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  setAuthMessage("Signing in...");
  const email = ui.authEmail.value.trim();
  const password = ui.authPassword.value;

  try {
    await signInWithEmailAndPassword(auth, email, password);
  } catch (error) {
    setAuthMessage(error.message || "Sign in failed.", "error");
  }
});

ui.signOutButton.addEventListener("click", async () => {
  try {
    await signOut(auth);
    setAuthMessage("Signed out.");
    showToast("Signed out");
  } catch (error) {
    setAuthMessage("Unable to sign out.", "error");
  }
});

ui.healthForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  setBusy(ui.healthForm, true);
  try {
    const data = await callPublic("/health");
    setOutput(ui.healthOutput, data, true);
    showToast("Health check ok.");
  } catch (error) {
    setOutput(ui.healthOutput, { error: error.message }, false);
    showToast(error.message);
  } finally {
    setBusy(ui.healthForm, false);
  }
});

ui.rootStatusButton.addEventListener("click", async () => {
  setBusy(ui.healthForm, true);
  try {
    const data = await callPublic("/");
    setOutput(ui.healthOutput, data, true);
    showToast("Root status ok.");
  } catch (error) {
    setOutput(ui.healthOutput, { error: error.message }, false);
    showToast(error.message);
  } finally {
    setBusy(ui.healthForm, false);
  }
});

ui.createOrderForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!state.user) {
    showToast("Sign in required.");
    return;
  }

  const form = event.currentTarget;
  const donationAmount = Number(form.donationAmount.value);
  if (!Number.isFinite(donationAmount) || donationAmount <= 0) {
    setOutput(ui.createOrderOutput, { error: "Enter a valid amount." }, false);
    showToast("Enter a valid amount.");
    return;
  }

  setBusy(form, true);
  try {
    const payload = { donationAmount };
    const clientRequestId = form.clientRequestId.value.trim();
    if (clientRequestId) {
      payload.clientRequestId = clientRequestId;
    }
    const data = await callPayment("/create-order", payload);
    setOutput(ui.createOrderOutput, data, true);
    showToast("Order created.");
  } catch (error) {
    setOutput(ui.createOrderOutput, { error: error.message }, false);
    showToast(error.message);
  } finally {
    setBusy(form, false);
  }
});

ui.verifyPaymentForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!state.user) {
    showToast("Sign in required.");
    return;
  }

  const form = event.currentTarget;
  setBusy(form, true);
  try {
    const payload = {
      transactionId: form.transactionId.value.trim(),
      razorpay_order_id: form.razorpay_order_id.value.trim(),
      razorpay_payment_id: form.razorpay_payment_id.value.trim(),
      razorpay_signature: form.razorpay_signature.value.trim(),
    };
    const data = await callPayment("/verify-payment", payload);
    setOutput(ui.verifyPaymentOutput, data, true);
    showToast("Payment verified.");
  } catch (error) {
    setOutput(ui.verifyPaymentOutput, { error: error.message }, false);
    showToast(error.message);
  } finally {
    setBusy(form, false);
  }
});

ui.paymentFailedForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!state.user) {
    showToast("Sign in required.");
    return;
  }

  const form = event.currentTarget;
  setBusy(form, true);
  try {
    const payload = {
      transactionId: form.transactionId.value.trim(),
    };
    const data = await callPayment("/payment-failed", payload);
    setOutput(ui.paymentFailedOutput, data, true);
    showToast("Payment flagged as failed.");
  } catch (error) {
    setOutput(ui.paymentFailedOutput, { error: error.message }, false);
    showToast(error.message);
  } finally {
    setBusy(form, false);
  }
});

ui.createUserForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!state.isAdmin) {
    showToast("Admin access required.");
    return;
  }

  const form = event.currentTarget;
  setBusy(form, true);
  try {
    const payload = {
      email: form.email.value.trim(),
      name: form.name.value.trim(),
      phone: form.phone.value.trim(),
      address: form.address.value.trim(),
      aadhaar: normalizeAadhaar(form.aadhaar.value),
      pan: normalizePan(form.pan.value),
    };
    const data = await callAdmin("/create-user", payload);
    setOutput(ui.createUserOutput, data, true);
    showToast("User created.");
  } catch (error) {
    setOutput(ui.createUserOutput, { error: error.message }, false);
    showToast(error.message);
  } finally {
    setBusy(form, false);
  }
});

ui.updateUserForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!state.isAdmin) {
    showToast("Admin access required.");
    return;
  }

  const form = event.currentTarget;
  setBusy(form, true);
  try {
    const payload = {
      userId: form.userId.value.trim(),
    };
    if (form.name.value.trim()) {
      payload.name = form.name.value.trim();
    }
    if (form.phone.value.trim()) {
      payload.phone = form.phone.value.trim();
    }
    if (form.address.value.trim()) {
      payload.address = form.address.value.trim();
    }
    if (form.aadhaar.value.trim()) {
      payload.aadhaar = normalizeAadhaar(form.aadhaar.value);
    }
    if (form.pan.value.trim()) {
      payload.pan = normalizePan(form.pan.value);
    }

    const data = await callAdmin("/update-user", payload);
    setOutput(ui.updateUserOutput, data, true);
    showToast("User updated.");
  } catch (error) {
    setOutput(ui.updateUserOutput, { error: error.message }, false);
    showToast(error.message);
  } finally {
    setBusy(form, false);
  }
});

ui.resetLinkForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (!state.isAdmin) {
    showToast("Admin access required.");
    return;
  }

  const form = event.currentTarget;
  const userId = form.userId.value.trim();
  if (!userId) {
    setOutput(ui.resetLinkOutput, { error: "User ID is required." }, false);
    showToast("Enter a user ID.");
    return;
  }
  setBusy(form, true);
  try {
    const payload = { userId };
    const data = await callAdmin("/reset-link", payload);
    setOutput(ui.resetLinkOutput, data, true);
    showToast("Reset link generated.");
  } catch (error) {
    setOutput(ui.resetLinkOutput, { error: error.message }, false);
    showToast(error.message);
  } finally {
    setBusy(form, false);
  }
});

ui.sendResetEmailButton.addEventListener("click", async () => {
  if (!state.isAdmin) {
    showToast("Admin access required.");
    return;
  }

  const email = ui.resetEmail.value.trim();
  if (!email) {
    setOutput(ui.resetLinkOutput, { error: "User email is required." }, false);
    showToast("Enter a user email.");
    return;
  }

  setBusy(ui.resetLinkForm, true);
  try {
    await sendPasswordResetEmail(auth, email);
    setOutput(ui.resetLinkOutput, `Reset email sent to ${email}.`, true);
    showToast("Reset email sent.");
  } catch (error) {
    const message = error?.message || "Could not send reset email.";
    setOutput(ui.resetLinkOutput, { error: message }, false);
    showToast(message);
  } finally {
    setBusy(ui.resetLinkForm, false);
  }
});

document.querySelectorAll("[data-copy]").forEach((button) => {
  button.addEventListener("click", async () => {
    const target = button.getAttribute("data-copy");
    if (!target) {
      return;
    }
    const output = document.getElementById(target);
    if (!output) {
      return;
    }
    const value = output.dataset.copyValue || output.textContent;
    if (!value || value === "No activity yet.") {
      showToast("Nothing to copy.");
      return;
    }
    try {
      await navigator.clipboard.writeText(value.trim());
      showToast("Copied to clipboard.");
    } catch (error) {
      showToast("Copy failed.");
    }
  });
});
