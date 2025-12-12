# Запуск программы

```
lua run.lua
```

# Запуск тестов

1. Установка luacov
```
luarocks install datafile
luarocks install luacov
```

2. Запуск тестов

```
lua -lluacov tests.lua
```

3. Генерация отчета по тестам

```
luacov
```

- Отчет будет находиться в файле `luacov.report.out`