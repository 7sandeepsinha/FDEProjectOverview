"""Allow: python -m meridian_workbench"""
 
import sys
 
from meridian_workbench.pipeline import main
 
if __name__ == "__main__":
    sys.exit(main())
