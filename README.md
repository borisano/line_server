# Salsify Line Server

A high-performance Ruby-based HTTP server that serves individual lines from text files using a REST API.

## Features

- **O(1) line access** using pre-built byte-offset index
- **Automatic memory/disk switching** for optimal performance at any scale
- **Memory efficient** - constant RAM usage regardless of file size
- **Multi-threaded** request handling with Puma web server
- **Persistent indexing** - index files cached between server restarts
- **Production ready** - tested with files up to 10GB+ (195M+ lines)
- **Concurrent support** - handles 500+ requests/second
- **REST API** - simple HTTP interface with proper status codes

## API

- `GET /lines/<line_index>` - Returns the specified line (1-indexed)
  - Returns HTTP 200 with line content on success
  - Returns HTTP 413 if line index exceeds file length

## Performance

### Tested Performance Characteristics

- **1GB file** (11.9M lines): 91MB index, ~0.5s indexing
- **10GB file** (195M lines): 1.6GB index, ~620s indexing
- **50GB file** (2.44B lines): ~3.8h generation time (13,645s), ~52min indexing (3,137s)
- **File access**: O(1) lookup regardless of file size or position
- **Memory usage**: Constant ~200MB RAM regardless of file size
- **Response time**: <10ms for any line in any size file

### Concurrency Performance (50GB File)

- **Sequential throughput**: 131+ req/s
- **Concurrent load (10 parallel)**: 805+ req/s  
- **High concurrency (50 parallel)**: 752+ req/s
- **Sustained load**: Handles 100+ concurrent users efficiently
- **Response times**: 1-2ms average under load
- **Edge case performance**: First/last line access in <10ms

### Automatic Scaling

- **Small files** (<5GB): Memory-based indexing for maximum speed
- **Large files** (≥5GB): Automatic disk-based indexing for memory efficiency
- **Index overhead**: ~8-15% of original file size
- **Persistent indexing**: Index files reused on server restart

## Configuration

The server can be configured using environment variables or a `.env` file:

```bash
# Copy the example configuration
cp .env.example .env
# Edit the configuration
nano .env
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SALSIFY_FILE_PATH` | *(required)* | Path to the file to serve |
| `PORT` | `4567` | Server port |
| `BIND` | `0.0.0.0` | Server bind address |
| `MEMORY_THRESHOLD_MB` | `512` | Memory limit for switching to disk indexing |
| `FORCE_DISK_INDEX` | `false` | Force disk-based indexing even for small files |
| `LOG_LEVEL` | `info` | Logging level (debug, info, warn, error) |
| `RACK_ENV` | `development` | Environment (development, test, production) |

### Example .env file

```env
SALSIFY_FILE_PATH=data/myfile.txt
PORT=4567
MEMORY_THRESHOLD_MB=1024
FORCE_DISK_INDEX=true
LOG_LEVEL=info
RACK_ENV=production
```

## Building and Running

### Local Development

```bash
./build.sh                    # Install dependencies

# Option 1: Use .env file configuration
cp .env.example .env         # Create configuration file
nano .env                    # Edit SALSIFY_FILE_PATH and other settings
./run.sh                     # Start server using .env configuration

# Option 2: Specify file directly
./run.sh <filename>          # Start server with specific file
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