#!/bin/bash

OUTPUT_DIR="/tmp/test_parallel_migration_$(date +%s)"
PROMPT="A beautiful sunset over mountains"
NUM_EXECUTIONS=10

mkdir -p "$OUTPUT_DIR"

echo "════════════════════════════════════════════════════════════════"
echo "  POST-MIGRATION PARALLEL EXECUTION TEST"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Testing: $NUM_EXECUTIONS parallel executions from parent directory"
echo "Prompt: $PROMPT"
echo "Output directory: $OUTPUT_DIR"
echo ""

declare -a PIDS
declare -a DIRS

for i in $(seq 1 $NUM_EXECUTIONS); do
  EXEC_DIR="$OUTPUT_DIR/execution_$i"
  mkdir -p "$EXEC_DIR/images"
  DIRS[$i]="$EXEC_DIR"
  
  (
    bash ./comfy-run-remote.sh \
      --prompt "$PROMPT" \
      --image-id "migration_$i" \
      --local-output "$EXEC_DIR/images"
  ) > "$EXEC_DIR/execution.log" 2>&1 &
  
  PIDS[$i]=$!
  echo "[SUBMIT] Execution $i submitted (PID: ${PIDS[$i]})"
done

echo ""
echo "[WAIT] Waiting for all $NUM_EXECUTIONS processes to complete..."
echo ""

FAILED=0
for i in $(seq 1 $NUM_EXECUTIONS); do
  if wait ${PIDS[$i]} 2>/dev/null; then
    echo "[DONE] Execution $i completed"
  else
    echo "[FAIL] Execution $i failed"
    FAILED=$((FAILED + 1))
  fi
done

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  RESULTS"
echo "════════════════════════════════════════════════════════════════"
echo ""

TOTAL_IMAGES=0
for i in $(seq 1 $NUM_EXECUTIONS); do
  EXEC_DIR="${DIRS[$i]}"
  IMAGES=$(find "$EXEC_DIR/images" -type f -name "*.png" 2>/dev/null | wc -l)
  TOTAL_IMAGES=$((TOTAL_IMAGES + IMAGES))
  if [ $IMAGES -gt 0 ]; then
    echo "[EXEC $i] ✓ Generated $IMAGES image(s)"
  else
    echo "[EXEC $i] ✗ No images"
  fi
done

echo ""
echo "Total Executions: $NUM_EXECUTIONS"
echo "Successful: $((NUM_EXECUTIONS - FAILED))"
echo "Failed: $FAILED"
echo "Total Images: $TOTAL_IMAGES"
echo ""

if [ $FAILED -eq 0 ] && [ $TOTAL_IMAGES -eq $NUM_EXECUTIONS ]; then
  echo "[PASS] Migration test successful!"
  exit 0
else
  echo "[FAIL] Migration test failed"
  exit 1
fi
