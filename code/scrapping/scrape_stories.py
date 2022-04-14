#!/usr/bin/env python3

urlArr = [ #{{{
        #"https://archiveofourown.org/works/28076361",
        "https://www.sofurry.com/view/1614335",
        #"https://docs.google.com/document/d/109iFskyibVgDFRRuuuTu1KkIeiVFICit_qBAgxl6deo",
        #"https://rentry.org/dtas003",
        #"https://ghostbin.com/paste/xWTWS/Tutamet",
        #"https://pastefs.com/pid/294416",
        #"https://pastebin.com/7mDKuh2L",
        #"https://pastes.psstaudio.com/post/16d0a7fda2db42428dd98d3967ddb8fe",
        #"https://mega.nz/folder/7X4USRYK#64dv5dVjKPZ-yWBsNC5Kmg/file/2CoQTDpK",
        #"https://www.furaffinity.net/view/39967487/",

] #}}}
dspt = { #{{{
        "archiveofourown.org" : {
            "login" : "https://archiveofourown.org/users/login",
            "usr" : "user[login]",
            "pwd" : 'user[password]',
            "token" : 'authenticity_token',
        },
        "www.sofurry.com" : {
            "login" : "https://www.sofurry.com/user/login",
            "usr" : "LoginForm[sfLoginUsername]",
            "pwd" : "LoginForm[sfLoginPassword]",
        },
        #"docs.google" :  {
        #},
        #"rentry" :  {
        #},
        #"ghostbin" : {
        #},
        #"pastefs" : {
        #},
        #"pastebin" : {
        #},
        #"pastes.psstaudio" : {
        #},
        #"mega.nz" : {
        #},
        #"hastebin" : {
        #},
        #"furaffinity" : {
        #},
} #}}}

# LOGIN CREDS
import csv
reader = csv.reader(open("/Users/azuhmier/.pwds"), delimiter=" ")
next(reader)
data = [tuple(row) for row in reader]
pwds = {}
for row in data :
    pwds[row[0]] = [row[1], row[2]]

# REQUESTS
import requests
from bs4 import BeautifulSoup
for url in urlArr :

    # Form DSPT key
    from urllib.parse import urlparse
    o = urlparse(url)

    #CREATE SESSION
    session = requests.Session()
    with requests.Session() as s:

        # PAYLOAD
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
        r = s.get(url)
        soup = BeautifulSoup(r.content, 'html.parser')

        # prettify
        text0 = soup.find('span', attrs={'id': "sfContentTitle"})
        text0 = text0.find_all(text=True)
        print('\n'.join(str(line) for line in text0))
        text = soup.find('div', attrs={'id': "sfContentDescription"})
        text = text.find_all(text=True)
        print('\n'.join(str(line) for line in text))
        text2 = soup.find('div', attrs={'id': "sfContentBody"})
        text2 = text2.find_all(text=True)
        print('\n'.join(str(line) for line in text2))

