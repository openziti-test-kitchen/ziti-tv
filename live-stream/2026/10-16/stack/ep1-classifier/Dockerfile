FROM python:3.12-slim

WORKDIR /app

ARG CLASSIFIER_MODEL=cardiffnlp/twitter-roberta-base-offensive
ENV CLASSIFIER_MODEL=${CLASSIFIER_MODEL} \
    HF_HOME=/models \
    PYTHONUNBUFFERED=1

# iproute2 provides `ss`, used to show from inside the container that nothing
# is listening on a TCP port. Drop it if you don't want it in your image.
RUN apt-get update && apt-get install -y --no-install-recommends iproute2 \
 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu \
 && pip install --no-cache-dir -r requirements.txt

# Download the weights at build time into HF_HOME. Without this, the first
# classify request pulls a few hundred MB while the caller waits.
RUN python -c "\
import os; from transformers import pipeline; \
p = pipeline('text-classification', model=os.environ['CLASSIFIER_MODEL']); \
print('baked', os.environ['CLASSIFIER_MODEL'], p.model.config.id2label)"

COPY classifier.py .

CMD ["python", "classifier.py"]
