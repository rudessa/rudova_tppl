import os
import sys


def analyze_file(filepath):
    """Анализирует текстовый файл и возвращает статистику"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()

        total_lines = len(lines)
        empty_lines = sum(1 for line in lines if line.strip() == '')
        total_chars = sum(len(line) for line in lines)

        char_freq = {}
        for line in lines:
            for char in line:
                char_freq[char] = char_freq.get(char, 0) + 1

        return total_lines, total_chars, empty_lines, char_freq

    except FileNotFoundError:
        print(f"Ошибка: файл '{filepath}' не найден")
        return None


def show_menu():
    """Показывает меню выбора"""
    print("\nВыберите, что показать (через пробел, например: 1 3 4):")
    print("1. Количество строк")
    print("2. Количество символов")
    print("3. Количество пустых строк")
    print("4. Частотный словарь символов")
    print("0. Показать всё")


def main():
    if len(sys.argv) > 1:
        filename = sys.argv[1]
    else:
        filename = input("Введите имя файла: ")

    result = analyze_file(filename)
    if not result:
        return

    total_lines, total_chars, empty_lines, char_freq = result

    show_menu()
    choice = input("\nВаш выбор: ").split()

    print("\n" + "="*50)

    if '0' in choice:
        choice = ['1', '2', '3', '4']

    if '1' in choice:
        print(f"Количество строк: {total_lines}")

    if '2' in choice:
        print(f"Количество символов: {total_chars}")

    if '3' in choice:
        print(f"Количество пустых строк: {empty_lines}")

    if '4' in choice:
        print("\nЧастотный словарь символов:")
        sorted_chars = sorted(
            char_freq.items(), key=lambda x: x[1], reverse=True)
        for char, count in sorted_chars:
            display_char = repr(char) if char in '\n\t\r' else char
            print(f"  {display_char}: {count}")


if __name__ == "__main__":
    main()
