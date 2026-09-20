# Exercise 6 — who may do what

**What changes in the code:** nothing.

**How it is deployed:** founders get the basic *Viewer* role (and the bucket's "convenience" grants
are removed so they cannot read the PDFs); the IT person gets *Owner* in the console; the API runs as
`notely-api@…` with two grants (the bucket, the secret) and the page as `notely-web@…` with none.
The Compute Engine default service account loses its grants.

**Run it:** `bash deploy/exercise6.sh`. Console click-paths and the honest "how hard was it"
answer: course document, Exercise 6.
