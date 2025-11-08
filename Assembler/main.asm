section .data
    filename db "data.txt", 0
    msg db "Среднее арифметическое разницы: ", 0
    err_msg db "Ошибка открытия файла", 10, 0
    newline db 10, 0
    max_size equ 100

section .bss
    file_content resb max_size
    x resd 7
    y resd 7
    diff resd 7
    sum resd 1
    avg resd 1
    buffer resb 20
    fd resd 1
    len resd 1

section .text
    global _start

_start:
    ; Открытие файла
    mov eax, 5           ; sys_open
    mov ebx, filename
    mov ecx, 0           ; O_RDONLY
    int 0x80
    
    test eax, eax
    js error_exit        ; если eax < 0, ошибка
    mov [fd], eax

    ; Чтение файла
    mov eax, 3           ; sys_read
    mov ebx, [fd]
    mov ecx, file_content
    mov edx, max_size
    int 0x80
    mov [len], eax

    ; Закрытие файла
    mov eax, 6           ; sys_close
    mov ebx, [fd]
    int 0x80

    ; Парсинг первой строки (массив x)
    mov esi, file_content
    mov edi, x
    call parse_array

    ; Парсинг второй строки (массив y)
    mov edi, y
    call parse_array

    ; Вычисление разностей
    mov ecx, 7
    xor esi, esi
    mov dword [sum], 0

calc_diff:
    mov eax, [x + esi*4]
    sub eax, [y + esi*4]
    mov [diff + esi*4], eax
    add [sum], eax
    inc esi
    dec ecx
    jnz calc_diff

    ; Вычисление среднего
    mov eax, [sum]
    cdq
    mov ebx, 7
    idiv ebx
    mov [avg], eax

    ; Вывод результата
    mov eax, 4
    mov ebx, 1
    mov ecx, msg
    mov edx, 33
    int 0x80

    mov eax, [avg]
    call print_int

    mov eax, 4
    mov ebx, 1
    mov ecx, newline
    mov edx, 1
    int 0x80

    ; Выход
    mov eax, 1
    xor ebx, ebx
    int 0x80

error_exit:
    mov eax, 4
    mov ebx, 1
    mov ecx, err_msg
    mov edx, 23
    int 0x80
    mov eax, 1
    mov ebx, 1
    int 0x80

; Функция парсинга массива из строки
; esi - указатель на текущую позицию в строке
; edi - указатель на массив для сохранения
parse_array:
    push eax
    push ebx
    push ecx
    push edx
    
    xor ecx, ecx         ; счетчик элементов
    
.parse_loop:
    xor eax, eax         ; текущее число
    xor ebx, ebx         ; флаг отрицательного числа
    
    ; Пропуск пробелов
.skip_spaces:
    mov bl, [esi]
    cmp bl, ' '
    jne .check_digit
    inc esi
    jmp .skip_spaces
    
.check_digit:
    cmp bl, 10           ; новая строка
    je .array_done
    cmp bl, 0            ; конец файла
    je .array_done
    cmp bl, ','
    je .skip_comma
    cmp bl, '0'
    jl .skip_char
    cmp bl, '9'
    jg .skip_char
    
    ; Чтение числа
.read_number:
    movzx ebx, byte [esi]
    cmp bl, '0'
    jl .save_number
    cmp bl, '9'
    jg .save_number
    sub bl, '0'
    imul eax, 10
    add eax, ebx
    inc esi
    jmp .read_number
    
.save_number:
    mov [edi + ecx*4], eax
    inc ecx
    cmp ecx, 7
    jge .array_done
    jmp .parse_loop
    
.skip_comma:
    inc esi
    jmp .parse_loop
    
.skip_char:
    inc esi
    jmp .parse_loop
    
.array_done:
    ; Пропуск до следующей строки
.skip_to_newline:
    mov bl, [esi]
    cmp bl, 10
    je .next_line
    cmp bl, 0
    je .done
    inc esi
    jmp .skip_to_newline
    
.next_line:
    inc esi
    
.done:
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; Функция вывода целого числа
print_int:
    push eax
    push ebx
    push ecx
    push edx
    
    mov ebx, 10
    xor ecx, ecx
    mov edi, buffer
    
    test eax, eax
    jns .positive
    neg eax
    push eax
    mov byte [edi], '-'
    inc edi
    pop eax

.positive:
.convert:
    xor edx, edx
    div ebx
    add dl, '0'
    push dx
    inc ecx
    test eax, eax
    jnz .convert

.pop_digits:
    pop dx
    mov [edi], dl
    inc edi
    loop .pop_digits

    mov eax, 4
    mov ebx, 1
    mov ecx, buffer
    sub edi, buffer
    mov edx, edi
    int 0x80

    pop edx
    pop ecx
    pop ebx
    pop eax
    ret