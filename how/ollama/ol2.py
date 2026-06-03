import requests

url = 'http://100.123.32.45:11434/api/generate'
data = {
    "model": "xmistral",
    "prompt": "Apa ibu kota Indonesia?",
    "stream": False
}

response = requests.post(url, json=data)
print(response.json()['response'])
