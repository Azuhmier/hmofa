#!/usr/bin/env python
from __future__ import print_function
import os.path
from googleapiclient.discovery import build
from google_auth_oauthlib.flow import InstalledAppFlow
from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials

# If modifying these scopes, delete the file token.json.
SCOPES = ['https://www.googleapis.com/auth/documents.readonly', 'https://www.googleapis.com/auth/documents', 'https://www.googleapis.com/auth/drive', 'https://www.googleapis.com/auth/drive.file']

# The ID of a sample document.
DOCUMENT_ID = '1ZzsZGneqTZ_hXg5gVdxDVudXvBjg2VZmsKlKdcaq-lo'

def main():
    """Shows basic usage of the Docs API.
    Prints the title of a sample document.
    """
    creds = None
    # The file token.json stores the user's access and refresh tokens, and is
    # created automatically when the authorization flow completes for the first
    # time.
    if os.path.exists('token.json'):
        creds = Credentials.from_authorized_user_file('token.json', SCOPES)
    # If there are no (valid) credentials available, let the user log in.
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file(
                '/Users/azuhmier/.credentials/credentials.json', SCOPES)
            creds = flow.run_local_server(port=0)
        # Save the credentials for the next run
        with open('token.json', 'w') as token:
            token.write(creds.to_json())

    service = build('docs', 'v1', credentials=creds)

    # Retrieve the documents contents from the Docs service.
    document = service.documents().get(documentId=DOCUMENT_ID).execute()

    print('The title of the document is: {}'.format(document.get('title')))
    # Format and append to doc
    completed_tasks = [1]
    for i in completed_tasks:
        # Write code to format date_text, which has date followed by all the tasks completed on that date
        requests = [
            {
                'insertText':
                {
                    'location': {
                        'index': 44,
                    },
                    'text': '00000000'
                }
            },
            {
                'updateTextStyle':
                {
                    "textStyle": {
                        "bold": "true",
                    },
                    "fields": "*",
                    "range": {
                        "startIndex": 1,
                        "endIndex": 1000
                    }
                }
            },
        ]

        result = service.documents().batchUpdate(documentId=DOCUMENT_ID, body={'requests': requests}).execute()




if __name__ == '__main__':
    main()
