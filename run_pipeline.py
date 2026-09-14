#!/usr/bin/env python
"""
Main Data Pipeline Orchestrator
Generates marketplace data, loads into database, and initializes analytical views.
"""

import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

from src.data_generator import generate_marketplace_dataset
from src.data_loading import load_all_tables


def main():
    """
    Orchestrates the complete data pipeline.
    """
    print("=" * 80)
    print("FOOD DELIVERY MARKETPLACE ANALYTICS — DATA PIPELINE")
    print("=" * 80)
    
    # Step 1: Generate synthetic dataset
    print("\n[STEP 1/2] Generating synthetic marketplace dataset...")
    print("-" * 80)
    success = generate_marketplace_dataset(num_orders=40000)
    if not success:
        print("[ERROR] Data generation failed.")
        sys.exit(1)
    print("[SUCCESS] Data generation complete.\n")
    
    # Step 2: Load into database
    print("\n[STEP 2/2] Loading data into database...")
    print("-" * 80)
    success = load_all_tables()
    if not success:
        print("[ERROR] Data loading failed.")
        sys.exit(1)
    print("[SUCCESS] Data loading complete.\n")
    
    print("=" * 80)
    print("[SUCCESS] PIPELINE COMPLETE — Database ready for analysis.")
    print("=" * 80)
    print("\nNext steps:")
    print("  1. Run notebooks: jupyter notebook notebooks/")
    print("  2. Launch dashboard: streamlit run dashboard/pages/01_overview.py")
    print()


if __name__ == "__main__":
    main()
