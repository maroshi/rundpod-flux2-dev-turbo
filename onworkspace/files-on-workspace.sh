#!/bin/bash

# Ensure we have /workspace in all scenarios
mkdir -p /workspace

if [[ ! -f /workspace/README.md ]]
then
	mv /README.md /workspace/README.md
else
	rm -f /README.md
fi

# Copy workflows from Docker image backup to persistent workspace
echo "ℹ️ [Moving workflows to persistent workspace]"
if [[ -d /workspace/workflows/ ]]; then
	# Check if it's empty
	if [[ -z "$(ls -A /workspace/workflows/)" ]]; then
		echo "ℹ️ Workflows directory exists but is empty, copying from backup..."
		mkdir -p /workspace/workflows/
		if [[ -d /root/workflows-backup/ ]]; then
			cp -r /root/workflows-backup/* /workspace/workflows/ 2>/dev/null || true
			echo "✅ Copied all workflows from backup to /workspace/workflows/"
		fi
	else
		echo "✅ Workflows directory already populated"
	fi
	ls -la /workspace/workflows/ | tail -n +2 | awk '{print "   " $9}'
else
	mkdir -p /workspace/workflows/
	if [[ -d /root/workflows-backup/ ]]; then
		cp -r /root/workflows-backup/* /workspace/workflows/ 2>/dev/null || true
		echo "✅ Copied workflows to /workspace/workflows/"
		ls -la /workspace/workflows/ | tail -n +2 | awk '{print "   " $9}'
	else
		echo "⚠️  No workflows backup found"
	fi
fi
