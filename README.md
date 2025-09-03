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

### Local Development

```bash
./build.sh           # Install dependencies
./run.sh <filename>  # Start server with file
```

### Docker

```bash
# Build Docker image
docker build -t salsify-line-server .

# Run with Docker
docker run -p 4567:4567 -v /path/to/data:/app/data \
  -e SALSIFY_FILE_PATH=/app/data/your_file.txt \
  salsify-line-server
```

### Production Deployment with Kamal

This project includes Kamal (formerly MRSK) configuration for easy containerized deployment.

#### Setup

1. Install Kamal (included in Gemfile):
```bash
bundle install
```

2. Configure your deployment:
   - Edit `config/deploy.yml` with your server details
   - Update environment-specific configs in `config/deploy.staging.yml` and `config/deploy.production.yml`
   - Set up your Docker registry credentials

3. Initial setup:
```bash
./deploy.sh staging setup    # Setup staging environment
./deploy.sh production setup # Setup production environment
```

#### Deployment Commands

```bash
# Deploy to staging
./deploy.sh staging deploy

# Deploy to production  
./deploy.sh production deploy

# Rollback deployment
./deploy.sh staging rollback

# View logs
./deploy.sh staging logs

# Open console
./deploy.sh staging console

# Check status
./deploy.sh staging status
```

#### Configuration

- **Servers**: Add your server IPs/hostnames to the `servers` section
- **Registry**: Configure Docker registry (Docker Hub, GitHub Container Registry, etc.)
- **Environment Variables**: Set `SALSIFY_FILE_PATH` and other env vars
- **Volumes**: Mount data directories for your text files
- **SSL**: Enable SSL/TLS with Let's Encrypt for production

## Architecture

Built with Ruby, Sinatra, and Puma for optimal performance.