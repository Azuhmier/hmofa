#!/usr/bin/env python3


## SETUP DIRECTOR
import os
tgt_dir = "/Users/azuhmier/hmofa/archives/"
isExist = os.path.exists(tgt_dir)
if not isExist:
    os.makedirs(tgt_dir)
archive_name = "/archive_"
number = 1
isExist = os.path.exists(tgt_dir+archive_name+str(number)+"/")
if isExist :
    while isExist :
        number += 1
        isExist = os.path.exists(tgt_dir+archive_name+str(number)+"/")
os.makedirs(tgt_dir+archive_name+str(number)+"/")
path = tgt_dir+archive_name+str(number)+"/"

## Import URLS
import json
f = open('/Users/azuhmier/hmofa/hmofa/code/test/.ohm/db/matches.json')
json = json.load(f)
urls = []
for h in json["objs"]["url"] :
    urls.append(h["val"])
url_test = [ #{{{
        #"https://archiveofourown.org/works/28076361",
        #"https://archiveofourown.org/works/32455084",
        #"https://www.sofurry.com/view/16143333",
        #"https://docs.google.com/document/d/109iFskyibVgDFRRuuuTu1KkIeiVFICit_qBAgxl6deo",
        "https://rentry.org/dtas003",
        #"https://ghostbin.com/paste/xWTWS/Tutamet",
        #"https://pastefs.com/pid/294416",
        #"https://pastebin.com/7mDKuh2L",
        #"https://pastes.psstaudio.com/post/16d0a7fda2db42428dd98d3967ddb8fe",
        #"https://mega.nz/folder/7X4USRYK#64dv5dVjKPZ-yWBsNC5Kmg/file/2CoQTDpK",
        #"https://www.furaffinity.net/view/22706328/",

] #}}}

## DSPT
dspt = { #{{{
        "archiveofourown.org" : {
            "login" : "https://archiveofourown.org/users/login",
            "usr" : "user[login]",
            "pwd" : 'user[password]',
            "token" : 'authenticity_token',
            "txt" : ['div', 'id', 'chapters'],
            "join" : 1,
            "find" : ['p','a'],
            "strip" : 1,
        },
        "www.sofurry.com" : {
            "login" : "https://www.sofurry.com/user/login",
            "usr" : "LoginForm[sfLoginUsername]",
            "pwd" : "LoginForm[sfLoginPassword]",
            "txt" : ['div', 'id', 'sfContentBody'],
            "find" : ['p','div'],
            "join" : 1,
        },
        #"www.furaffinity.net" : {
        #    "login" : "https://www.furaffinity.net/login",
        #    "usr" : "name",
        #    "pwd" : "pass",
        #    "txt" : ['div', 'class', 'submission-description user-submitted-links'],
        #    "find" : ['i'],
        #    "join" : 1,
        #    "metod" : "login",
        #},
        #"docs.google" :  {
        #},
        #"mega.nz" : {
        #},
} #}}}

## LOGIN CREDS
import csv
reader = csv.reader(open("/Users/azuhmier/.pwds"), delimiter=" ")
next(reader)
data = [tuple(row) for row in reader]
pwds = {}
for row in data :
    pwds[row[0]] = [row[1], row[2]]

## REQUESTS
import requests
from bs4 import BeautifulSoup
data = []
import time

total_urls = len(urls)
proccessed_urls = -1

for url in urls :
    proccessed_urls += 1
    print(str(proccessed_urls) +'/'+ str(total_urls), end='\r')
    # Form DSPT key
    from urllib.parse import urlparse
    o = urlparse(url)
    #CREATE SESSION
    session = requests.Session()
    with requests.Session() as s:

        if o.netloc in dspt :
            # PAYLOAD
            headers = {
                    'User-Agent': 'Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.10; rv:75.0) Gecko/20100101 Firefox/75.0'
                    }
            payload = {
                dspt[o.netloc]["usr"] : pwds[o.netloc][0],
                dspt[o.netloc]["pwd"] : pwds[o.netloc][1],
            }

            # TOKENS
            r_init = s.get(dspt[o.netloc]["login"])
            soup  = BeautifulSoup(r_init.content, 'html.parser')

            if "token" in dspt[o.netloc] :
                token = soup.find('input', attrs={'name': dspt[o.netloc]["token"]})
                if not token :
                    print('could not find `authenticity_token` on login form')
                else :
                    payload.update(
                        { dspt[o.netloc]["token"] : token.get('value').strip() }

                    )

            # Submit Credentials
            p = s.post(dspt[o.netloc]["login"], data=payload)

            ## An authorised request.
            r = s.get(url, headers=headers)
            soup = BeautifulSoup(r.content, 'html.parser')

            # Get TEXT
            raw = soup.find(dspt[o.netloc]["txt"][0], attrs={dspt[o.netloc]["txt"][1]:dspt[o.netloc]["txt"][2]})
            if not raw :
                html = s.get(url)
                soup = BeautifulSoup(html.content, 'html.parser')
                data = {"html" : soup.prettify}
            else :
                raw_text = raw.find_all(dspt[o.netloc]["find"])
                text = []
                for line in raw_text :
                    if "strip" in dspt[o.netloc] :
                        subhtml = str(line).replace("\n", ' ').replace("<br/>", "\n")
                    else :
                        subhtml = str(line).replace("\n", ' ')
                    subsoup = BeautifulSoup(subhtml, 'html.parser')
                    string= subsoup.text

                    string = string.rstrip()
                    if dspt[o.netloc]["join"] :
                        add = "\n"
                    else :
                        add = ""
                    text.append((string+add))

                data = {"html" : str(soup), "txt" : text}
        else :
            html = s.get(url)
            data = {"html" : html.content}

    dirname = o.netloc+"_"+o.path.replace("/","_")
    dire = path+dirname

    isExist = os.path.exists(dire)
    number = 1
    if isExist :
        while isExist :
            isExist = os.path.exists(dire+"_"+str(number))
            number += 1
        os.makedirs(dire+"_"+str(number))
    else :
        os.makedirs(dire)
    f = open(dire+"/content.html", "w")
    f.write(str(data["html"]))
    f.close()

    if "txt" in data :
        with open(dire+"/content.txt", "w") as f:
            for item in data["txt"]:
                f.write("%s\n" % item)
    time.sleep(2)


print("Scrapping Complete")
