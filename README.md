Agent simulator for queue onboarding

Usage:

```powershell
node agent-core/queue_agent.js http://localhost:3000 MyHost "optional-public-key"
```

The script will POST to `/api/agents/queue` and poll `/api/agents/queue/:id/status` until approved or rejected.
