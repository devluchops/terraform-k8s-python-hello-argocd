from flask import Flask, jsonify, render_template_string
import os
import socket
import time
import threading
from datetime import datetime, timedelta

app = Flask(__name__)

# Global counters for metrics
request_count = 0
start_time = datetime.utcnow()
health_check_count = 0

@app.route('/')
def hello_world():
    global request_count
    request_count += 1
    return jsonify({
        "message": "Hello World from Python!",
        "version": "1.0.0",
        "environment": os.getenv("ENVIRONMENT", "development"),
        "hostname": socket.gethostname(),
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "request_number": request_count
    })

@app.route('/health')
def health_check():
    global health_check_count
    health_check_count += 1
    return jsonify({
        "status": "healthy",
        "service": "hello-world-python",
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "check_number": health_check_count
    })

@app.route('/info')
def info():
    return jsonify({
        "service": "hello-world-python",
        "version": "1.0.0",
        "description": "A simple Python Flask application for Kubernetes deployment",
        "endpoints": {
            "/": "Main hello world endpoint",
            "/health": "Health check endpoint",
            "/info": "Service information endpoint",
            "/k8s": "Kubernetes environment information",
            "/metrics": "Application metrics",
            "/load/<seconds>": "Simulate CPU load for X seconds",
            "/slow": "Slow response (3 seconds)",
            "/fail": "Force 500 error",
            "/demo": "Interactive demo page"
        }
    })

@app.route('/k8s')
def kubernetes_info():
    return jsonify({
        "kubernetes": {
            "pod_name": os.getenv("HOSTNAME", socket.gethostname()),
            "pod_ip": os.getenv("POD_IP", "unknown"),
            "node_name": os.getenv("NODE_NAME", "unknown"),
            "namespace": os.getenv("POD_NAMESPACE", "unknown"),
            "service_account": os.getenv("SERVICE_ACCOUNT", "unknown")
        },
        "aws": {
            "availability_zone": os.getenv("AWS_AVAILABILITY_ZONE", "unknown"),
            "region": os.getenv("AWS_REGION", "unknown")
        },
        "resources": {
            "cpu_request": os.getenv("CPU_REQUEST", "unknown"),
            "memory_request": os.getenv("MEMORY_REQUEST", "unknown"),
            "cpu_limit": os.getenv("CPU_LIMIT", "unknown"),
            "memory_limit": os.getenv("MEMORY_LIMIT", "unknown")
        }
    })

@app.route('/metrics')
def metrics():
    uptime = datetime.utcnow() - start_time
    return jsonify({
        "requests_total": request_count,
        "health_checks_total": health_check_count,
        "uptime_seconds": int(uptime.total_seconds()),
        "uptime_human": str(uptime).split('.')[0],
        "start_time": start_time.isoformat() + "Z",
        "current_time": datetime.utcnow().isoformat() + "Z"
    })

@app.route('/load/<int:seconds>')
def simulate_load(seconds):
    if seconds > 30:
        return jsonify({"error": "Maximum 30 seconds allowed"}), 400
    
    start = time.time()
    end_time = start + seconds
    
    # Simulate CPU load
    while time.time() < end_time:
        pass
    
    actual_time = time.time() - start
    return jsonify({
        "message": f"Simulated {seconds}s of CPU load",
        "actual_duration": round(actual_time, 2),
        "hostname": socket.gethostname()
    })

@app.route('/slow')
def slow_response():
    time.sleep(3)
    return jsonify({
        "message": "This was a slow response (3 seconds)",
        "hostname": socket.gethostname(),
        "timestamp": datetime.utcnow().isoformat() + "Z"
    })

@app.route('/fail')
def force_failure():
    return jsonify({
        "error": "Simulated failure",
        "hostname": socket.gethostname(),
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }), 500

@app.route('/demo')
def demo_page():
    html_template = '''
<!DOCTYPE html>
<html>
<head>
    <title>Python Hello World - Demo</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .endpoint { margin: 15px 0; padding: 15px; background: #f8f9fa; border-radius: 5px; border-left: 4px solid #007bff; }
        .button { background: #007bff; color: white; padding: 8px 16px; text-decoration: none; border-radius: 4px; margin: 5px; display: inline-block; }
        .button:hover { background: #0056b3; }
        .danger { border-left-color: #dc3545; }
        .warning { border-left-color: #ffc107; }
        .success { border-left-color: #28a745; }
        .info { background: #e3f2fd; padding: 20px; border-radius: 5px; margin: 20px 0; }
        pre { background: #f8f9fa; padding: 15px; border-radius: 5px; overflow-x: auto; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🐍 Python Hello World - Interactive Demo</h1>
        
        <div class="info">
            <strong>Pod:</strong> {{ hostname }}<br>
            <strong>Environment:</strong> {{ environment }}<br>
            <strong>Uptime:</strong> <span id="uptime">Loading...</span><br>
            <strong>Total Requests:</strong> <span id="requests">Loading...</span>
        </div>

        <h2>🔍 Information Endpoints</h2>
        <div class="endpoint success">
            <strong>Basic Info:</strong> 
            <a href="/" class="button">GET /</a>
            <a href="/info" class="button">GET /info</a>
        </div>
        
        <div class="endpoint success">
            <strong>Kubernetes Info:</strong> 
            <a href="/k8s" class="button">GET /k8s</a>
            <a href="/metrics" class="button">GET /metrics</a>
        </div>

        <h2>🏥 Health & Monitoring</h2>
        <div class="endpoint success">
            <strong>Health Check:</strong> 
            <a href="/health" class="button">GET /health</a>
        </div>

        <h2>🧪 Testing Endpoints</h2>
        <div class="endpoint warning">
            <strong>Performance Tests:</strong> 
            <a href="/load/5" class="button">5s Load</a>
            <a href="/load/10" class="button">10s Load</a>
            <a href="/slow" class="button">Slow Response</a>
        </div>
        
        <div class="endpoint danger">
            <strong>Failure Simulation:</strong> 
            <a href="/fail" class="button">Force Error 500</a>
        </div>

        <h2>📊 Live Metrics</h2>
        <pre id="metrics">Loading metrics...</pre>
    </div>

    <script>
        function updateMetrics() {
            fetch('/metrics')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('uptime').textContent = data.uptime_human;
                    document.getElementById('requests').textContent = data.requests_total;
                    document.getElementById('metrics').textContent = JSON.stringify(data, null, 2);
                })
                .catch(error => {
                    document.getElementById('metrics').textContent = 'Error loading metrics: ' + error;
                });
        }
        
        // Update metrics every 5 seconds
        updateMetrics();
        setInterval(updateMetrics, 5000);
    </script>
</body>
</html>
    '''
    
    return render_template_string(html_template, 
                                hostname=socket.gethostname(),
                                environment=os.getenv("ENVIRONMENT", "development"))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=False)