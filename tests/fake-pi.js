#!/usr/bin/env node

const fs = require('fs');
const readline = require('readline');

const scenario = process.env.NINE_FAKE_PI_SCENARIO || 'success';
const logFile = process.env.NINE_FAKE_PI_LOG;
let promptCount = 0;

function appendLog(message) {
  if (!logFile) return;
  fs.appendFileSync(logFile, message.replace(/\n/g, '\\n') + '\n');
}

function send(obj) {
  process.stdout.write(JSON.stringify(obj) + '\n');
}

function responseForPrompt() {
  promptCount += 1;

  if (scenario === 'success') {
    return '{"insert_text":"HELLO"}';
  }

  if (scenario === 'visual-success' || scenario === 'visual-delayed-success') {
    return '{"replacement_text":"nine"}';
  }

  if (scenario === 'visual-linewise') {
    return '{"replacement_text":"new one\\nnew two"}';
  }

  if (scenario === 'visual-retry-once') {
    if (promptCount === 1) return 'not json';
    return '{"replacement_text":"nine"}';
  }

  if (scenario === 'retry-once') {
    if (promptCount === 1) return 'not json';
    return '{"insert_text":"HELLO"}';
  }

  if (scenario === 'fail-three') {
    return promptCount % 2 === 0 ? '{"insert_text":123}' : 'not json';
  }

  if (scenario === 'multiline') {
    return '{"insert_text":"HELLO\\nWORLD"}';
  }

  return '{"insert_text":"HELLO"}';
}

const rl = readline.createInterface({
  input: process.stdin,
  crlfDelay: Infinity,
});

rl.on('line', (line) => {
  if (!line.trim()) return;

  let command;
  try {
    command = JSON.parse(line);
  } catch (err) {
    return;
  }

  if (command.type !== 'prompt') {
    send({
      id: command.id,
      type: 'response',
      command: command.type,
      success: true,
    });
    return;
  }

  appendLog(command.message || '');
  const text = responseForPrompt();

  const emitResponse = () => {
    send({
      id: command.id,
      type: 'response',
      command: 'prompt',
      success: true,
    });

    send({
      type: 'message_start',
      message: { role: 'assistant', content: [] },
    });
    send({
      type: 'message_update',
      message: { role: 'assistant', content: [] },
      assistantMessageEvent: { type: 'text_delta', delta: text },
    });
    send({
      type: 'message_end',
      message: { role: 'assistant', content: [] },
    });
    send({
      type: 'agent_end',
      messages: [],
    });
  };

  if (scenario === 'delayed-success' || scenario === 'visual-delayed-success') {
    setTimeout(emitResponse, 150);
    return;
  }

  emitResponse();
});
