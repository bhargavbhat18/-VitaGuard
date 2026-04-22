import sys
import os

# Add the backend directory to the path so main.py can be imported
# and main.py can import from the 'app' directory correctly.
backend_path = os.path.join(os.path.dirname(__file__), '..', 'backend')
sys.path.append(backend_path)

from main import app
