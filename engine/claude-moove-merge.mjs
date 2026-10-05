// CLAUDE MOOVE merge note. Claude Moove installs this only when a chat was continued on two laptops.
// At session start it looks for a one-time note left for this exact chat; with none waiting it exits at once.
// Each note is used once and then deleted. Run with --install [settings.json] to register it as a SessionStart hook.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const notesFile = path.join(os.homedir(), '.claude', 'claude-moove', 'pending-merges.json');

if (process.argv[2] === '--install') {
  const settingsFile = process.argv[3] || path.join(os.homedir(), '.claude', 'settings.json');
  const settings = fs.existsSync(settingsFile) ? JSON.parse(fs.readFileSync(settingsFile, 'utf8').replace(/^\uFEFF/, '')) : {};
  const sessionStart = ((settings.hooks ??= {}).SessionStart ??= []);
  if (!JSON.stringify(sessionStart).includes('claude-moove-merge')) {
    const me = fileURLToPath(import.meta.url).replace(/\\/g, '/');
    sessionStart.push({ hooks: [{ type: 'command', command: `node "${me}"`, timeout: 15 }] });
    fs.writeFileSync(settingsFile, JSON.stringify(settings, null, 2) + '\n');
  }
  process.exit(0);
}

try {
  if (!fs.existsSync(notesFile)) process.exit(0);
  const input = JSON.parse(fs.readFileSync(0, 'utf8').replace(/^\uFEFF/, '') || '{}');
  const notes = JSON.parse(fs.readFileSync(notesFile, 'utf8').replace(/^\uFEFF/, ''));
  const note = notes[input.session_id];
  if (!note) process.exit(0);

  delete notes[input.session_id];
  if (Object.keys(notes).length) fs.writeFileSync(notesFile, JSON.stringify(notes, null, 2));
  else fs.unlinkSync(notesFile);

  // What the other copy has that this one doesn't: every message after the point where the two split.
  const mine = new Set(readChat(input.transcript_path).map(e => e.uuid).filter(Boolean));
  const theirs = readChat(note.otherTranscript).filter(e => e.uuid && !mine.has(e.uuid)).map(asText).filter(Boolean);
  let story = theirs.join('\n\n');
  if (story.length > 20000) story = '[...earlier part cut...]\n\n' + story.slice(-20000);

  process.stdout.write(JSON.stringify({
    systemMessage: `Clawd: this chat was also continued on your other laptop. That copy is kept as "${note.otherTitle}", and I've caught up on what happened there.`,
    hookSpecificOutput: {
      hookEventName: 'SessionStart',
      additionalContext:
        `Claude Moove note (shown once): this chat was also continued on another laptop before the two were brought together. ` +
        `That version is kept as the separate chat "${note.otherTitle}" (full transcript: ${note.otherTranscript}). ` +
        `These are the messages from that version after the two copies split:\n\n${story || '(no readable messages)'}\n\n` +
        `Keep this in mind. If the user wants, help them bring the two versions together.`
    }
  }));
} catch {
  process.exit(0);
}

function readChat(file) {
  try {
    return fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '').split('\n').filter(Boolean).flatMap(line => {
      try { return [JSON.parse(line)]; } catch { return []; }
    });
  } catch { return []; }
}

function asText(e) {
  if (e.isMeta || e.isCompactSummary || e.isSidechain || !e.message) return '';
  const c = e.message.content;
  const t = (typeof c === 'string' ? c : Array.isArray(c) ? c.filter(b => b.type === 'text').map(b => b.text).join('\n') : '').trim();
  if (!t) return '';
  return e.type === 'user' ? 'User: ' + t : e.type === 'assistant' ? 'Claude: ' + t : '';
}
