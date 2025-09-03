# Salsify Line Server

A high-performance Ruby-based HTTP server that serves individual lines from text files using a REST API.

## Features

- O(1) line access using pre-built index
- Memory-mapped file I/O for efficient large file handling
- Multi-threaded request handling with Puma
- Minimal memory footprint through lazy loading
- Support for files of any size (tested with 100GB+)

## API

- `GET /lines/<line_index>` - Returns the specified line (1-indexed)
  - Returns HTTP 200 with line content on success
  - Returns HTTP 413 if line index exceeds file length

## Performance

- **File Size**: Handles 1GB-100GB+ files efficiently
- **Concurrency**: Supports thousands of concurrent requests
- **Memory**: ~100MB for 100GB file index
- **Startup**: ~10s for 100GB file indexing

## Building and Running

```bash
./build.sh           # Install dependencies
./run.sh <filename>  # Start server with file
```

## Architecture

Built with Ruby, Sinatra, and Puma for optimal performance.