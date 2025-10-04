def analyze_file(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    total_lines = len(lines)
    total_chars = sum(len(line) for line in lines)
    empty_lines = sum(1 for line in lines if line.strip() == '')
    
    char_freq = {}
    for line in lines:
        for char in line:
            char_freq[char] = char_freq.get(char, 0) + 1
    
    return total_lines, total_chars, empty_lines, char_freq


def main():
    filename = input("Введите имя файла: ")
    
    print("\nВыберите, что хотите увидеть:")
    print("1 - Количество строк")
    print("2 - Количество символов")
    print("3 - Количество пустых строк")
    print("4 - Частотный словарь символов")
    print("Введите номера через пробел (например: 1 2 4): ")
    
    choices = input().split()
    
    total_lines, total_chars, empty_lines, char_freq = analyze_file(filename)
    
    print("\n--- Результаты анализа ---")
    
    if '1' in choices:
        print(f"Количество строк: {total_lines}")
    
    if '2' in choices:
        print(f"Количество символов: {total_chars}")
    
    if '3' in choices:
        print(f"Количество пустых строк: {empty_lines}")
    
    if '4' in choices:
        print("Частотный словарь символов:")
        for char, count in sorted(char_freq.items()):
            if char == '\n':
                print(f"  '\\n': {count}")
            elif char == ' ':
                print(f"  ' ': {count}")
            else:
                print(f"  '{char}': {count}")


if __name__ == "__main__":
    main()