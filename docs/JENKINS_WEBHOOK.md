# GitHub webhook for Jenkins

On GitHub, open the repository's **Settings → Webhooks → Add webhook**:

- **Payload URL:** `http://<JENKINS_IP>:8080/github-webhook/`
- **Content type:** `application/json`
- **Which events would you like to trigger this webhook?** Select **Just the push event**.
- Save the webhook and check its **Recent Deliveries** for an HTTP success response.

The Jenkins VM network security group and host firewall must allow inbound TCP 8080 from the webhook sender. Restrict access to administrator and GitHub webhook source CIDRs where practical; do not expose Jenkins broadly. The pipeline also polls SCM every two minutes, so builds can still start without a working webhook.

## Jenkins on a local network

GitHub cannot reach a private LAN address such as `192.168.x.x`. For local Jenkins, use Poll SCM only by disabling/removing the `githubPush()` trigger in a local-only Jenkinsfile, or provide a public HTTPS tunnel (for example ngrok) and use its externally reachable `/github-webhook/` URL. Do not leave a temporary tunnel or an unrestricted Jenkins port open longer than needed.
