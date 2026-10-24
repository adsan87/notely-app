# Exercise 8 — a review, not a deployment

**What changes in the code:** nothing.

Evaluate the architecture against the AWS, Azure and Google Cloud Well-Architected Frameworks and
propose what should change. The reference memo is in the course document, Exercise 8. Two of its
proposals build on Exercises 5 and 6: an external load balancer with a domain, a certificate and a WAF
in front of the page (the only public door), and service-to-service authentication, so that only the
page's identity may call the API (Cloud Run Invoker granted to `notely-web@…`, the proxy sending an ID
token) on top of the internal ingress.
