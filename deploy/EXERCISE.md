# Exercise 4 — "Attach file": one PDF per note, stored in a bucket

**What changes in the code:**
- Backend: `src/attachments.js` (writes and reads objects in the bucket named by `ATTACHMENTS_BUCKET`
  with the API's own identity) and two routes in `src/index.js`: `POST /api/notes/:id/attachment`
  (multipart field `file`, PDF only, up to 10 MB) and `GET /api/notes/:id/attachment` (streams the PDF).
  Deleting a note deletes its file. New dependencies: `multer`, `@google-cloud/storage`.
- Frontend: an **Attach file** button and the attachment link in `src/App.jsx`; `uploadAttachment`
  and `attachmentUrl` in `src/api.js`.
- The database row keeps the file's name, object path, size and type (columns already in the table).

**How it is deployed:** one private bucket in `europe-north1` (uniform access, versioning), the API's
identity gets *Storage Object Admin* on that bucket only, and both services get new revisions.

**Run it:** `bash deploy/exercise4.sh`. Console click-paths: course document, Exercise 4.

**Check it:** attach a PDF to a note in the page; `curl -o out.pdf …/api/notes/1/attachment`;
the direct file address `https://storage.googleapis.com/notely-attachments-…/notes/1/…` answers 403.
