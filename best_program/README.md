# Инструкция по запуску программы в Linux

## 1. Установка Lua и LuaRocks
```
sudo apt update
```

### Установка интерпретатора Lua
```
sudo apt install lua 5.4.7
```

### Установка пакетного менеджера LuaRocks
```
sudo apt install luarocks
```

## 2. Установка библиотеки LuaSocket
```
sudo luarocks install luasocket
```

## 3. Подготовка файла с кодом
- Сохраните весь предоставленный Lua-код в файл с именем main.lua.
- Отредактируйте main.lua: Удалите или закомментируйте первые четыре строки, отвечающие за ручную настройку путей для Windows, так как LuaRocks настроит их автоматически в Linux

```
local LIB_ROOT = "D:\\lualibs_windows\\" 

package.cpath = package.cpath .. ";" .. LIB_ROOT .."luasocket\\?.dll"
package.cpath = package.cpath .. ";" .. LIB_ROOT .. "luasocket\\mime\\?.dll"
package.path = package.path .. ";" .. LIB_ROOT .. "luasocket\\?.lua"
```

## 4. Запуск программы
```
lua main.lua
```

### Для остановки программы нажмите Ctrl+C
### После запуска данные будут записываться в файл sensor_data.txt в той же директории.