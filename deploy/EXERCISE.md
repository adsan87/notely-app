# Exercise 6 — who may do what

**What changes in the code:** nothing.

**Before you run it — the founders' group.** Each founder signs in with their own Google account. Put
both accounts in one Google group and give the roles to the group, not to the people:
- Project in an organization: **IAM & Admin > Groups > Create** (needs Google Workspace or Cloud Identity).
- Project without an organization (the usual case for a course project): create the group in Google
  Groups (`groups.google.com`) and add the two accounts. Its address looks like `…@googlegroups.com`.
Write the group's address in `FOUNDERS_GROUP` at the top of `deploy/exercise6.sh`.

**How it is deployed:**
- The **founders' group** gets four read-only roles on the project: *Cloud Run Viewer*, *Cloud SQL
  Viewer*, *Storage Object Viewer* and *Storage Bucket Viewer* (Beta; it lets the Buckets page list the
  bucket). They can open the services, the database and the bucket, and read the PDFs; they cannot
  change or delete anything. Anyone given *Viewer* one by one before loses it.
- The **API** runs as `notely-api@…` with two grants: *Storage Object Admin* on the bucket and *Secret
  Manager Secret Accessor* on the database password. The **page** runs as `notely-web@…` with no grant.
- The **broad grants go**: the Compute Engine default service account, which both services used until
  now, loses its grants on the bucket and the secret, and the project *Editor* role.
- You, the IT person, keep the *Owner* role you already have; nobody else gets it.

**Run it:** `bash deploy/exercise6.sh`. Console click-paths and the honest "how hard was it"
answer: course document, Exercise 6.

**Check it:** as a founder, in a private window: the Cloud Run, Cloud SQL and Cloud Storage pages open,
and every button that changes something is disabled or answers with a permission error.
`Cloud Run > notely-api > Security` shows `notely-api@…`; the app still uploads and downloads a PDF.
