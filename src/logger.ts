type Level = "debug" | "info" | "warn" | "error";

interface LogFields {
  [key: string]: unknown;
}

function write(level: Level, fields: LogFields | undefined, message: string) {
  const line = {
    time: new Date().toISOString(),
    level,
    msg: message,
    ...(fields ?? {})
  };
  const output = JSON.stringify(line);
  if (level === "error") {
    console.error(output);
  } else if (level === "warn") {
    console.warn(output);
  } else {
    console.log(output);
  }
}

export interface Logger {
  debug(message: string, fields?: LogFields): void;
  info(message: string, fields?: LogFields): void;
  warn(message: string, fields?: LogFields): void;
  error(message: string, fields?: LogFields): void;
}

export function createLogger(enabled = true): Logger {
  return {
    debug: (message, fields) => {
      if (enabled) write("debug", fields, message);
    },
    info: (message, fields) => {
      if (enabled) write("info", fields, message);
    },
    warn: (message, fields) => {
      if (enabled) write("warn", fields, message);
    },
    error: (message, fields) => {
      if (enabled) write("error", fields, message);
    }
  };
}
