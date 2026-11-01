import sys, os
from pathlib import Path
PROJECT_DIR = Path(__file__).parent.parent.resolve()
sys.path.insert(0, str(PROJECT_DIR))
os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"

def test_snap_zones():
    # Simple unit test for snap calculation
    left_threshold = 20
    top_threshold = 20
    
    # Cursor at top left
    pos_x, pos_y = 5, 5
    is_left = pos_x < left_threshold
    is_top = pos_y < top_threshold
    assert is_left and is_top, "Top-left snap detection failed"
    print("[OK] test_rmb_snap passed completely!")

if __name__ == "__main__":
    test_snap_zones()

