# Exercise 5 — reachable only by the app

**What changes in the code:** nothing.

**How it is deployed:** the database gets a private address inside the project's `default` network
(private services access), then loses its public address and the `0.0.0.0/0` authorized network.
The API reaches the private address through Direct VPC egress (`DB_HOST` changes to the private IP).
The bucket gets *public access prevention* enforced. The two Cloud Run services keep their public
HTTPS URLs — they are the app.

**Run it:** `bash deploy/exercise5.sh`. Console click-paths and the "what to tell the lawyer"
paragraph: course document, Exercise 5.
