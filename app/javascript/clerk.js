const clerkReady = () => new Promise((resolve) => {
  if (window.Clerk) return resolve(window.Clerk)

  const startedAt = Date.now()
  const timer = window.setInterval(() => {
    if (window.Clerk) {
      window.clearInterval(timer)
      resolve(window.Clerk)
    } else if (Date.now() - startedAt > 10000) {
      window.clearInterval(timer)
      resolve(null)
    }
  }, 50)
})

const initializeClerk = async () => {
  const auth = document.querySelector("#clerk-auth")
  if (!auth || auth.dataset.initialized) return

  const clerk = await clerkReady()
  if (!clerk) return

  auth.dataset.initialized = "true"
  await clerk.load({ ui: { ClerkUI: window.__internal_ClerkUICtor } })
  if (clerk.isSignedIn) {
    clerk.mountUserButton(auth)
  } else {
    clerk.mountSignIn(auth, { signUpForceRedirectUrl: window.location.href })
  }

  updateVoteControls(clerk.isSignedIn)
  clerk.addListener(({ user }) => updateVoteControls(Boolean(user)))
}

document.addEventListener("turbo:load", initializeClerk)
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initializeClerk)
} else {
  initializeClerk()
}

const updateVoteControls = (signedIn) => {
  document.querySelectorAll("[data-vote-url] button").forEach((button) => { button.disabled = !signedIn })
}

document.addEventListener("click", async (event) => {
  const button = event.target.closest("[data-vote-action]")
  if (!button) return

  const clerk = window.Clerk
  if (!clerk?.session) return

  const controls = button.closest("[data-vote-url]")
  const token = await clerk.session.getToken()
  const removing = button.dataset.voteAction === "remove"
  const response = await fetch(controls.dataset.voteUrl, {
    method: removing ? "DELETE" : "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${token}`,
      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
    },
    body: removing ? undefined : JSON.stringify({ value: button.dataset.voteAction })
  })
  if (!response.ok) return

  const { votes } = await response.json()
  controls.querySelector("[data-up-count]").textContent = votes.up
  controls.querySelector("[data-down-count]").textContent = votes.down
})
