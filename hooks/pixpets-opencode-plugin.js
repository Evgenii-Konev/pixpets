// PixPets plugin for OpenCode
// Tracks session status and writes to ~/.pixpets/sessions/<session_id>.json
// Install: copy to ~/.config/opencode/plugins/pixpets.js

import { writeFileSync, mkdirSync, unlinkSync } from "node:fs";
import { join, basename } from "node:path";
import { homedir } from "node:os";

const SESSIONS_DIR = join(homedir(), ".pixpets", "sessions");

function writeSession(sessionId, status, project) {
  mkdirSync(SESSIONS_DIR, { recursive: true });
  const file = join(SESSIONS_DIR, `${sessionId}.json`);

  if (status === "remove") {
    try {
      unlinkSync(file);
    } catch {}
    return;
  }

  const data = {
    pid: process.ppid || process.pid,
    status,
    project: project || process.cwd(),
    project_name: basename(project || process.cwd()),
    agent: "opencode",
    session_id: sessionId,
    interactive: true,
    updated_at: Math.floor(Date.now() / 1000),
  };

  writeFileSync(file, JSON.stringify(data, null, 2));
}

/** @type {import("@opencode-ai/plugin").Plugin} */
export const PixPetsPlugin = async (ctx) => {
  const projectDir = ctx.directory || ctx.worktree || process.cwd();

  return {
    event: async ({ event }) => {
      switch (event.type) {
        case "session.created": {
          const sessionId = event.properties.info.id;
          writeSession(sessionId, "idle", projectDir);
          break;
        }
        case "session.status": {
          const sessionId = event.properties.sessionID;
          const status = event.properties.status;
          if (status.type === "busy") {
            writeSession(sessionId, "working", projectDir);
          } else if (status.type === "idle") {
            writeSession(sessionId, "idle", projectDir);
          }
          // retry → still working
          else if (status.type === "retry") {
            writeSession(sessionId, "working", projectDir);
          }
          break;
        }
        case "session.idle": {
          writeSession(event.properties.sessionID, "idle", projectDir);
          break;
        }
        case "session.deleted": {
          const sessionId = event.properties.info.id;
          writeSession(sessionId, "remove", projectDir);
          break;
        }
      }
    },

    "tool.execute.before": async (input) => {
      writeSession(input.sessionID, "waiting", projectDir);
    },

    "tool.execute.after": async (input) => {
      writeSession(input.sessionID, "working", projectDir);
    },
  };
};
