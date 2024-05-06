pgrok
=====

This application is a simple HTTP-only alternative to sish and ngrok.

It uses an unmodified openssh server and some scripting around it to force SSH reverse tunneling onto connecting clients.

A client might connect pgrok reverse tunnel like this:

```bash
ssh -R '0:localhost:8080' pgrok@example.org
```

This allocates a random available port on the server-side and configured HTTP traffic to that port.