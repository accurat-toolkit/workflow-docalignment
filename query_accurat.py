"""This script provides command-line access to MT-Serverland.

Author: Mateja Verlic <mateja.verlic@zemanta.com>
Author: Sabine Hunsicker <Sabine.Hunsicker@dfki.de>
Author: Christian Federmann <cfedermann@dfki.de>
"""

import os
import httplib2
import json
import mimetools
import time
import datetime
import sys
import codecs

HTTP = httplib2.Http()
BASE_URL = "http://www.dfki.de/mt-serverland/dashboard/api/"
TOKEN = "16196d25"

def create_accurat_request(article, request_id, text, src, tgt):
    """This method creates a translation request for MT-Serverland."""
    shortname = "accurat_%s_%s" % (request_id,
                                       datetime.datetime.now().isoformat())

    # submit a new translation request: multipart/form-data
    contents = {}
    contents['token'] = TOKEN
    contents['shortname'] = shortname
    contents['worker'] = 'AccuratWorker'
    contents['source_language'] = src
    contents['target_language'] = tgt

    crlf = '\r\n'
    boundary = '-----' + mimetools.choose_boundary() + '-----'
    body = []
    for (key, value) in contents.items():
        body.append ('--' + boundary)
        body.append('Content-Disposition: form-data; name="{0}"'.format(key))
        body.append('')
        body.append(value)
    body.append ('--' + boundary)
    body.append ('Content-Disposition: form-data; ' +
                  'name="source_text"; ' +
                  'filename="{0}"'.format(article))
    body.append('Content-Type: text/plain; charset="UTF-8"')
    body.append('')
    body.extend(text.split('\n'))
    body.append ('--' + boundary)
    body.append('')
    body = (crlf.join(body)).encode("utf-8")
    content_type = 'multipart/form-data; boundary={0}'.format(boundary)
    header = {'Content-type': content_type, 'Content-length': str(len(body))}

    response = HTTP.request(BASE_URL + 'requests/',
                            method = 'POST', body = body, headers = header)
    print('create new request:')
    print('response status:', response[0].status)
    print(response)
    if response[0].status == 201:
        print('response (json):', json.loads(response[1]))

    return shortname


def delete_accurat_request(request):
    """This method deletes a finished translation request."""
    response = HTTP.request (BASE_URL + 'requests/%s/?token={0}'.format(TOKEN) %
                             request, method = 'DELETE')
    print('response:', response[0].status, response[0].reason)


if __name__ == '__main__':
    if len(sys.argv) < 5:
        print 'USAGE'
        print '\tpython %s FILELIST SRC TGT TempDir' % sys.argv[0]
        print
        print '\tFILELIST text file with paths to files to be translated'
        print '\tSRC/TGT languages in iso-639-2 code (eng, ger, ...)'
        print '\tTempDir directory to store the translation result)'
        sys.exit(0)

    ARTICLES_FILE = sys.argv[1]
    SRC = sys.argv[2]
    TGT = sys.argv[3]
    TEMP=sys.argv[4]
    delimiter='###'


    for test_article in codecs.open(ARTICLES_FILE, 'r', 'utf-8'):
        test_article_file = test_article.strip()
        #t=re.sub(r'\\', r'/', test_article_file).split('/')
        t=test_article_file.split(os.path.sep)
        if ":" in t[0]:
            t[0]=t[0].replace(':','@@@')
           # print t[0]
        fullname=delimiter.join(t)
        output=TEMP+os.path.sep+fullname         
        #output = "%s.%s-%s" % (test_article_file, SRC, TGT)
        if os.path.exists(output):
            print("%s already translated" % output)
            continue
        article_id = test_article_file.split(os.path.sep)[-1]
        test_article_file=test_article_file+".SENT"
        article_text = codecs.open(test_article_file, 'r', 'utf-8').read()
        request_shortname = create_accurat_request(test_article_file,
                                                   article_id, article_text,
                                                   SRC, TGT)
        accurat_request = {    'test_article_file': test_article_file,
                            'article_id': article_id,
                            'article_text': article_text
                            }

        while (True):
            # query the server for translation requests
            server_response = HTTP.request (BASE_URL + \
                                     'requests/%s/?token={0}'.format(TOKEN) %
                                     request_shortname, method = 'GET')
            if server_response[0].status == 200:
                accurat_response = json.loads(server_response[1])

                if accurat_response["ready"]:
                    # query the server for translation requests
                    server_response = HTTP.request (BASE_URL + \
                                             'results/%s/?token={0}'.\
                                             format(TOKEN) % request_shortname,
                                             method = 'GET')
                    if server_response[0].status == 200:
                        accurat_result = json.loads(server_response[1])
                        delete_accurat_request(request_shortname)

                        f = open(output, "w")
                        f.write(accurat_result['result'].encode('utf-8'))
                        f.close()

                    break

            time.sleep(30)
