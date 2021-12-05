#!/usr/bin/env python3
# help([object])
# DEPRECATION: Configuring installation scheme with distutils config files is
# deprecated and will no longer work in the near future. If you are using a
# Homebrew or Linuxbrew Python, please see discussion at
# https://github.com/Homebrew/homebrew-core/issues/76621
#from selenium import webdriver
#import scrapy

# VARS
#output_dir = '~/hmofa/scrapes/'
#user = 'azuhmer'

# CVS
#import csv
#reader = csv.reader(open("/Users/azuhmier/hmofa/.pwds"), delimiter="\t")
#pwds = []
#line_count = 0
#col_0 = ''
#col_1 = ''
#for row in reader:
#    if line_count == 0:
#        col_0 = row[0]
#        col_1 = row[1]
#    else:
#        pwds.append({col_0:row[0],col_1:row[1]})
#    line_count += 1

# URLS
url1 = 'https://archiveofourown.org/works/28161555'
url2 = 'https://archiveofourown.org/works/28161555#main'
url3 = 'https://archiveofourown.org/works/28161555?view_full_work=true'

# Start the session
import requests
session = requests.Session()
r1 = session.get(url1)
r2 = session.get(url2)
r3 = session.get(url3)

# "parse" html
from bs4 import BeautifulSoup
soup = BeautifulSoup(r3.content, 'html.parser')
print(soup.prettify())

#page = requests.get(url1)
#soup = BeautifulSoup(page.content, 'html.parser')
#print(soup.prettify())
#html = list(soup.children)[2]
#body = list(html.children)[3]
#script = soup.find_all('script')[-2]
#print([type(item) for item in list(soup.children)])
#r = requests.get(url, cookies=cookies)
#r = requests.get(url)
#soup = BeautifulSoup(r.content, "html.parser")
#print(soup.prettify())

#session = requests.Session()
#s = session.get(url)
#payload = {
#}
#s = session.post("https://www.chess.com/login_check", data=payload)
#s = session.get(url)
#print(s.text)

#s = session.get(url)
#session = requests.Session()
#r = requests.get(url)
#soup = BeautifulSoup(r.text, 'html.parser')
#print(soup.find(id="tos_agree"))
# Create the payload
#payload = {
#    '_username':user,
#    '_password':pwds[0]['pwd'],
#}
#soup = BeautifulSoup(s.text, 'html.parser')
#print(soup.title)
#print(soup.title.name)
#print(soup.title.string)
#print(soup.title.parent.name)
#print(soup.p)
#div_list = soup.find_all('div')
#print(div_list);
