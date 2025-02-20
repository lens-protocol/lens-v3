import * as fs from 'fs';
import * as path from 'path';

interface Event {
  address: string;
  blockHash: string;
  blockNumber: number;
  logIndex: number;
  removed: boolean;
  topics: string[];
  transactionHash: string;
  transactionIndex: number;
}

function parseEvents(filePath: string): Event[] {
  const content = fs.readFileSync(filePath, 'utf-8');
  const events: Event[] = [];
  let currentEvent: Partial<Event> = {};

  // Split content into lines and process each line
  const lines = content.split('\n');

  for (let line of lines) {
    line = line.trim();

    // Skip empty lines
    if (!line) continue;

    // New event starts with "- address:"
    if (line.startsWith('- address:')) {
      if (Object.keys(currentEvent).length > 0) {
        events.push(currentEvent as Event);
      }
      currentEvent = {};
      currentEvent.address = line.replace('- address:', '').trim();
      continue;
    }

    // Parse other fields
    if (line.includes(':')) {
      const [key, ...valueParts] = line.split(':');
      const trimmedKey = key.trim();
      const value = valueParts.join(':').trim();

      switch (trimmedKey) {
        case 'blockHash':
        case 'transactionHash':
          currentEvent[trimmedKey] = value;
          break;
        case 'blockNumber':
        case 'logIndex':
        case 'transactionIndex':
          currentEvent[trimmedKey] = parseInt(value);
          break;
        case 'removed':
          currentEvent[trimmedKey] = value === 'true';
          break;
        case 'topics':
          currentEvent.topics = [];
          break;
      }
    } else if (line.startsWith('0x') && currentEvent.topics) {
      // Add topic to current event's topics array
      currentEvent.topics.push(line.trim());
    }
  }

  // Add the last event
  if (Object.keys(currentEvent).length > 0) {
    events.push(currentEvent as Event);
  }

  return events;
}

function main() {
  try {
    const inputPath = path.join(__dirname, 'events_processed.txt');
    const outputPath = path.join(__dirname, 'events.json');

    const events = parseEvents(inputPath);

    // Write parsed events to JSON file
    fs.writeFileSync(
      outputPath,
      JSON.stringify(events, null, 2),
      'utf-8'
    );

    console.log(`Successfully parsed ${events.length} events and saved to ${outputPath}`);
  } catch (error) {
    console.error('Error parsing events:', error);
  }
}

main();
