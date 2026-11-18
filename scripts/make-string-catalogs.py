#!/usr/bin/env python3
"""Writes App/Localizable.xcstrings and App/InfoPlist.xcstrings: Czech source, English translation.

Usage: scripts/make-string-catalogs.py <exported en.xliff>
Export the keys first with
  xcodebuild -exportLocalizations -project Daybook.xcodeproj -localizationPath <dir> -exportLanguage en
English comes from scripts/english.json and plural variations from scripts/plurals.json. The script
fails when a key has no English, so a new string cannot ship untranslated.
"""
import json, os, sys
import xml.etree.ElementTree as ET

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
english = json.load(open(os.path.join(root, 'scripts', 'english.json'), encoding='utf-8'))
plurals = json.load(open(os.path.join(root, 'scripts', 'plurals.json'), encoding='utf-8'))
ns = '{urn:oasis:names:tc:xliff:document:1.2}'
files = {}
for f in ET.parse(sys.argv[1]).getroot().iter(ns + 'file'):
    name = f.get('original').split('/')[-1]
    for unit in f.iter(ns + 'trans-unit'):
        files.setdefault(name, []).append(unit.get('id'))

def unit(value):
    return {'stringUnit': {'state': 'translated', 'value': value}}

missing = []
for name, keys in files.items():
    strings = {}
    for key in sorted(set(keys)):
        if key in plurals:
            strings[key] = {'localizations': {
                lang: {'variations': {'plural': {form: unit(text) for form, text in forms.items()}}}
                for lang, forms in plurals[key].items()}}
        elif key in english:
            strings[key] = {'localizations': {'en': unit(english[key])}}
        else:
            missing.append(key)
    catalog = {'sourceLanguage': 'cs', 'strings': strings, 'version': '1.0'}
    with open(os.path.join(root, 'App', name), 'w', encoding='utf-8') as out:
        json.dump(catalog, out, ensure_ascii=False, indent=2, sort_keys=True)
        out.write('\n')
    print(name, len(strings))
if missing:
    print('No English for:', *missing, sep='\n  ')
    sys.exit(1)
