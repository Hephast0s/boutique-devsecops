#!/usr/bin/python
#
# Copyright 2018 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from concurrent import futures
import argparse
import os
import smtplib
import sys
import time
import grpc
import traceback
from email.mime.text import MIMEText
from jinja2 import Environment, FileSystemLoader, select_autoescape, TemplateError
from google.api_core.exceptions import GoogleAPICallError
from google.auth.exceptions import DefaultCredentialsError

import demo_pb2
import demo_pb2_grpc
from grpc_health.v1 import health_pb2
from grpc_health.v1 import health_pb2_grpc

from opentelemetry import trace
from opentelemetry.instrumentation.grpc import GrpcInstrumentorServer
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

# @TODO: Temporarily removed in https://github.com/GoogleCloudPlatform/microservices-demo/pull/3196
# import googlecloudprofiler

from logger import getJSONLogger
logger = getJSONLogger('emailservice-server')

# Loads confirmation email template from file
env = Environment(
    loader=FileSystemLoader('templates'),
    autoescape=select_autoescape(['html', 'xml'])
)
template = env.get_template('confirmation.html')

class BaseEmailService(demo_pb2_grpc.EmailServiceServicer):
  def Check(self, request, context):
    return health_pb2.HealthCheckResponse(
      status=health_pb2.HealthCheckResponse.SERVING)
  
  def Watch(self, request, context):
    return health_pb2.HealthCheckResponse(
      status=health_pb2.HealthCheckResponse.UNIMPLEMENTED)

class EmailService(BaseEmailService):
  def __init__(self):
    raise Exception('cloud mail client not implemented')
    super().__init__()

  @staticmethod
  def send_email(client, email_address, content):
    response = client.send_message(
      sender = client.sender_path(project_id, region, sender_id),
      envelope_from_authority = '',
      header_from_authority = '',
      envelope_from_address = from_address,
      simple_message = {
        "from": {
          "address_spec": from_address,
        },
        "to": [{
          "address_spec": email_address
        }],
        "subject": "Your Confirmation Email",
        "html_body": content
      }
    )
    logger.info("Message sent: {}".format(response.rfc822_message_id))

  def SendOrderConfirmation(self, request, context):
    email = request.email
    order = request.order

    try:
      confirmation = template.render(order = order)
    except TemplateError as err:
      context.set_details("An error occurred when preparing the confirmation mail.")
      logger.error(err.message)
      context.set_code(grpc.StatusCode.INTERNAL)
      return demo_pb2.Empty()

    try:
      EmailService.send_email(self.client, email, confirmation)
    except GoogleAPICallError as err:
      context.set_details("An error occurred when sending the email.")
      print(err.message)
      context.set_code(grpc.StatusCode.INTERNAL)
      return demo_pb2.Empty()

    return demo_pb2.Empty()

class DummyEmailService(BaseEmailService):
  def SendOrderConfirmation(self, request, context):
    logger.info('A request to send order confirmation email to {} has been received.'.format(request.email))
    return demo_pb2.Empty()

class SMTPEmailService(BaseEmailService):
  """Real email delivery over SMTP (non-GCP environments).

  Enabled only when SMTP_HOST is set; otherwise the dummy service is used.
  This is a non-GCP environment shim: upstream only implements a Google Cloud
  Mail client, which is unavailable on this cluster.
  """
  def SendOrderConfirmation(self, request, context):
    email = request.email
    order = request.order
    try:
      confirmation = template.render(order=order)
    except TemplateError as err:
      context.set_details("An error occurred when preparing the confirmation mail.")
      context.set_code(grpc.StatusCode.INTERNAL)
      return demo_pb2.Empty()

    host = os.environ.get('SMTP_HOST')
    port = int(os.environ.get('SMTP_PORT', '1025'))
    sender = os.environ.get('SMTP_FROM', 'no-reply@boutique.local')
    user = os.environ.get('SMTP_USER')
    password = os.environ.get('SMTP_PASSWORD')
    use_tls = os.environ.get('SMTP_TLS', '').lower() in ('1', 'true', 'yes')
    use_ssl = os.environ.get('SMTP_SSL', '').lower() in ('1', 'true', 'yes')

    msg = MIMEText(confirmation, 'html')
    msg['Subject'] = 'Your Confirmation Email'
    msg['From'] = sender
    msg['To'] = email

    try:
      if use_ssl:
        smtp = smtplib.SMTP_SSL(host, port, timeout=20)
      else:
        smtp = smtplib.SMTP(host, port, timeout=20)
      with smtp:
        if use_tls and not use_ssl:
          smtp.ehlo()
          smtp.starttls()
          smtp.ehlo()
        if user:
          smtp.login(user, password)
        smtp.sendmail(sender, [email], msg.as_string())
    except Exception as err:
      logger.error('failed to send order confirmation email to {}: {}'.format(email, err))
      context.set_details("An error occurred when sending the email.")
      context.set_code(grpc.StatusCode.INTERNAL)
      return demo_pb2.Empty()

    logger.info('order confirmation email sent to {} via SMTP {}:{}'.format(email, host, port))
    return demo_pb2.Empty()

class HealthCheck():
  def Check(self, request, context):
    return health_pb2.HealthCheckResponse(
      status=health_pb2.HealthCheckResponse.SERVING)

def start(dummy_mode):
  server = grpc.server(futures.ThreadPoolExecutor(max_workers=10),)
  service = None
  if dummy_mode:
    service = DummyEmailService()
  elif os.environ.get('SMTP_HOST'):
    service = SMTPEmailService()
  else:
    raise Exception('non-dummy mode not implemented yet')

  demo_pb2_grpc.add_EmailServiceServicer_to_server(service, server)
  health_pb2_grpc.add_HealthServicer_to_server(service, server)

  port = os.environ.get('PORT', "8080")
  logger.info("listening on port: "+port)
  server.add_insecure_port('[::]:'+port)
  server.start()
  try:
    while True:
      time.sleep(3600)
  except KeyboardInterrupt:
    server.stop(0)

def initStackdriverProfiling():
  project_id = None
  try:
    project_id = os.environ["GCP_PROJECT_ID"]
  except KeyError:
    # Environment variable not set
    pass

  # @TODO: Temporarily removed in https://github.com/GoogleCloudPlatform/microservices-demo/pull/3196
  # for retry in range(1,4):
  #   try:
  #     if project_id:
  #       googlecloudprofiler.start(service='email_server', service_version='1.0.0', verbose=0, project_id=project_id)
  #     else:
  #       googlecloudprofiler.start(service='email_server', service_version='1.0.0', verbose=0)
  #     logger.info("Successfully started Stackdriver Profiler.")
  #     return
  #   except (BaseException) as exc:
  #     logger.info("Unable to start Stackdriver Profiler Python agent. " + str(exc))
  #     if (retry < 4):
  #       logger.info("Sleeping %d to retry initializing Stackdriver Profiler"%(retry*10))
  #       time.sleep (1)
  #     else:
  #       logger.warning("Could not initialize Stackdriver Profiler after retrying, giving up")
  return


if __name__ == '__main__':
  logger.info('starting the email service in dummy mode.')

  # Profiler
  try:
    if "DISABLE_PROFILER" in os.environ:
      raise KeyError()
    else:
      logger.info("Profiler enabled.")
      initStackdriverProfiling()
  except KeyError:
      logger.info("Profiler disabled.")

  # Tracing
  try:
    if os.environ["ENABLE_TRACING"] == "1":
      otel_endpoint = os.getenv("COLLECTOR_SERVICE_ADDR", "localhost:4317")
      trace.set_tracer_provider(TracerProvider())
      trace.get_tracer_provider().add_span_processor(
        BatchSpanProcessor(
            OTLPSpanExporter(
            endpoint = otel_endpoint,
            insecure = True
          )
        )
      )
    grpc_server_instrumentor = GrpcInstrumentorServer()
    grpc_server_instrumentor.instrument()

  except (KeyError, DefaultCredentialsError):
      logger.info("Tracing disabled.")
  except Exception as e:
      logger.warn(f"Exception on Cloud Trace setup: {traceback.format_exc()}, tracing disabled.") 
  
  start(dummy_mode = 'SMTP_HOST' not in os.environ)
