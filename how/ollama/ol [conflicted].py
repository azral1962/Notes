import ollama

response = ollama.chat(model='llama3', messages=[
  {
    'role': 'user',
    'content': 'Apa itu AI?',
  },
])
print(response['message']['content'])
