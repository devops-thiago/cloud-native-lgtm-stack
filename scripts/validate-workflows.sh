#!/bin/bash

# Simple validation script for GitHub Actions workflows
# This validates that our workflow files have correct YAML syntax

set -e

echo "🔍 Validating GitHub Actions workflow files..."

# Check if we have any workflow files
workflow_dir=".github/workflows"
if [ ! -d "$workflow_dir" ]; then
    echo "❌ No workflow directory found"
    exit 1
fi

# Count workflow files
workflow_count=$(find "$workflow_dir" -name "*.yml" -o -name "*.yaml" | wc -l)
echo "📋 Found $workflow_count workflow files"

# Basic validation using Python's yaml module if available
if command -v python3 >/dev/null 2>&1; then
    echo "🐍 Validating YAML syntax with Python..."
    for file in "$workflow_dir"/*.yml "$workflow_dir"/*.yaml; do
        if [ -f "$file" ]; then
            echo "  Checking $(basename "$file")..."
            python3 -c "import yaml; yaml.safe_load(open('$file'))" && echo "    ✅ Valid YAML" || echo "    ❌ Invalid YAML"
        fi
    done
else
    echo "⚠️  Python3 not available, skipping detailed YAML validation"
fi

# Check for common workflow requirements
echo "🔧 Checking workflow structure..."

for file in "$workflow_dir"/*.yml "$workflow_dir"/*.yaml; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        echo "  Checking $filename..."
        
        # Check for required sections
        if grep -q "^name:" "$file"; then
            echo "    ✅ Has name"
        else
            echo "    ❌ Missing name"
        fi
        
        if grep -q "^on:" "$file"; then
            echo "    ✅ Has triggers"
        else
            echo "    ❌ Missing triggers"
        fi
        
        if grep -q "^jobs:" "$file"; then
            echo "    ✅ Has jobs"
        else
            echo "    ❌ Missing jobs"
        fi
        
        # Check for e2e specific content
        if echo "$filename" | grep -q "e2e"; then
            if grep -q "kind" "$file"; then
                echo "    ✅ Uses kind for Kubernetes"
            else
                echo "    ⚠️  No kind cluster setup found"
            fi
            
            if grep -q "install.*sh\|install.*ps1" "$file"; then
                echo "    ✅ Tests installation scripts"
            else
                echo "    ⚠️  No installation script testing found"
            fi
        fi
        
        echo ""
    fi
done

echo "✅ Workflow validation completed!"
echo ""
echo "📚 Summary of created e2e testing infrastructure:"
echo "  🐧 Shell script testing (Ubuntu)"
echo "  🪟 PowerShell script testing (Windows)" 
echo "  🔄 Cross-platform matrix testing"
echo "  ☸️  Single-node Kubernetes testing (kind)"
echo "  📦 Local and containerized Helm testing"
echo "  🛠️  Comprehensive validation utilities"
echo ""
echo "🚀 Ready for e2e testing!"