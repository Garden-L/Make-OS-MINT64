[org 0]									; 코드의 시작 어드레스를 0으로 설정
[BITS 16]								; 이하의 코드는 16비트 코드로 설정
	
SECTION .TEXT 							; TEXT 세그먼트 정의
	
jmp 0x07C0:START 						; CS=0x07C0, IP(PC)=0x5(START의 인덱스)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;	MINT64 OS에 관련된 환경 설정 값
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TOTALSECTORCOUNT dw 1024				; 부트로더를 제외한 MINT64 OS 이미지의 크기
										; 최대 1152 섹터 (0x90000byte)까지 가능


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;	코드영역
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
START:									; 0x5
	mov ax, 0x07C0
	mov ds, ax							;ds 레지스터를 파일이 로드되어있는 메모리 첫 주소
	mov ax, 0xB800						;비디오 메모리 시작 주소
	mov es, ax							;es=0xB800 계산 될때 0xB800 < 4로 계산
	
	;스택 시작 위치 0x0000:0000-0x0000:FFFF 영역 64KBz크기
	mov ax, 0x0000
	mov ss, ax
	mov sp, 0xFFFE						; 스택 포인터 레지스터
	mov bp, 0xFFFE						; 베이스 포인터 레지스터
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;	화면지우기 녹색으로 초기화
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov si, 0							;SI=0 원본 인덱스 레지스터
	
.SCREENCLEARLOOP:						;clear monitor
	mov byte [es:si], 0 				; 비디오 메모리의 0을 넣을 경우 클리어됨
	mov byte [es:si + 1], 0x0A 			;바탕색=밝은녹색
	
	add si, 2							; 2byte 인덱스
	
	cmp si, 80 * 25 * 2					;화면전체크기= 80*25, 문자인식 = 1, 색조정=1
										;si 와 일치하지 않으면 Zero register = 1
	jl .SCREENCLEARLOOP					; 
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;	화면 상단에 시작 메세지 출력
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	push MESSAGE1						; 출력할 주소값을 스택 상단에 삽입
	push 0								; 출력할 Y 좌표(0)을 스택에 삽입
	push 0								; 화면 X 좌표(0)을 스택에 삽입
	call PRINTMESSAGE					; PRINTMESSAGE 함수 호출
	add sp, 6							; 삽입한 파라미터 제거

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;	OS 이미지를 로딩한다는 메세지 출력
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	push IMAGELOADINGMESSAGE
	push 1
	push 0
	call PRINTMESSAGE
	add sp, 6

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;	디스크에서 OS 이미지를 로딩
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;	디스크를 읽기 전에 먼저 리셋
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

RESETDISK:								; 디스크 리셋 코드 시작
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;	BIOS Reset Function 호출
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; 서비스 번호 0, 드라이브 번호(0 = Floppy)
	mov ax, 0							; reset disk system
	mov dl, 0
	int 0x13

	jc HANDLEDISKERROR
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;	디스크에서 섹터를 읽음
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; 디스크에서 내용을 메모리로 복사할 어드레스 0x10000으로 설정
	mov si, 0x1000
	mov es, si
	mov bx, 0x0000

	mov di, word [TOTALSECTORCOUNT]

READDATA:								; 디스크를 읽는 코드의 시작
	cmp di, 0
	je READEND							; 다 읽었으면 읽기 끝
	sub di, 0x1							; 복사할 섹터수 1 감소
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; BIOS Read Function 호출
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov ah, 0x02						; 서비스 번호 2(read sector from drive)
	mov al, 0x1							; 읽을 섹터수 1개
	mov ch, byte [TRACKNUMBER]			; 읽을 트랙 번호 설정
	mov cl, byte [SECTORNUMBER]			; 읽을 섹터 번호 설정
	mov dh, byte [HEADNUMBER]			; 읽을 헤드 번호 설정
	mov dl, 0x00 						; 읽을 드라이브 설정 = floppy
	int 0x13
	
	jc HANDLEDISKERROR					; 에러발생하면 오류 함수로 이동 (CF = 1)

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; 복사할 어드레스와 트랙, 헤드, 섹터 어드레스 계산
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	add si, 0x0020						; 512(0x200)바이트만큼 읽었으므로, 이를 세그먼트 레지스터 값으로 변환
	mov es, si							; ES 세그먼트 레지스터에 더해서 어드레스를 한 섹터만큼 증가

	mov al, byte [SECTORNUMBER]			; 섹터 번호를 AL 레지스터에 설정
	add al, 0x01						; 섹터 번호를 1 증가
	mov byte [SECTORNUMBER], al			; 증가시킨 섹터 번호를 SECTORNUMBER에 다시 설정
	cmp al, 19							; 증가시킨 섹터 번호를 19와비교
	jl READDATA							; 섹터 번호가 19 미만이라면 READDATA로 이동

	; 마지막 섹터까지 읽었으면 (섹터번호가 19이면) 헤드를 토글(0->1, 1->0)gkrh
	; 섹터 번호를 1로 설정
	xor byte [HEADNUMBER], 0x01
	mov byte [SECTORNUMBER], 0x01		; 섹터 번호를 다시 1로 설정

	; 만약 헤드가 1->0으로 바뀌었으면 양쪽 헤드를 모두 읽은 것이므로 아래로 이동
	; 트랙 번호를 1증가
	cmp byte[HEADNUMBER], 0x00 			; 헤드번호를 0x00과 비교
	jne READDATA						; 헤드 번호가 0이 아니면 READDATA 이동

	; 트랙을 1 증가시킨 후 다시 섹터 읽기로 이동
	add byte [TRACKNUMBER], 0x01		; 트랙번호 1증가
	jmp READDATA

READEND:
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; OS 이미지가 완료되었다는 메세지를 출력
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	push LOADINGCOMPLETEMESSAGE
	push 1								; y 좌표
	push 20								; x 좌표
	call PRINTMESSAGE
	add sp, 6


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; 로딩한 가상 OS 이미지 실행
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	jmp 0x1000:0x0000


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;	함수 코드 영역
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 디스크 에러 함수
HANDLEDISKERROR:
	push DISKERRORMESSAGE				; 에러메세지
	push 1								; y좌표
	push 20								; x좌표
	call PRINTMESSAGE
	add sp, 6;

	jmp $

; 메세지 출력함수
PRINTMESSAGE:
	push bp
	mov bp, sp


	push es
	push si
	push di
	push ax
	push cx
	push dx

	mov ax, 0xB800
	mov es, ax

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; X, Y 좌표로 비디오 메모리의 어드레스를 계산함
	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov ax, word [bp + 6]				; 파라미터에 접근하기 위해 bp + 6
	mov si, 160							
	mul si								; si * ax 
	mov di, ax

	; x 좌표를 이용해서 2를 곱한 후 최종 어드레스를 구함
	mov ax, word[bp+4]
	mov si, 2
	mul si
	add di, ax

	; 출력할 문자열의 어드레스
	mov si, word [bp + 8]

.MESSAGELOOP:							;메세지 출력 함수
	mov cl, byte [MESSAGE1 + si]		;CX레지스터 하위 8비트에 
										;MESSAGE1에 SI OFFSET

	cmp cl, 0
	je .MESSAGEEND

	mov byte [es:di], cl

	add si, 1
	add di, 2

	jmp .MESSAGELOOP

.MESSAGEEND:
	pop dx
	pop cx
	pop ax
	pop di
	pop si
	pop es
	pop bp
	ret 							; 함수를 호출한 다음 코드의 위치로 복귀

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 데이터 영역
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 부트로더 시작 메시지
MESSAGE1:	db 'MINT64 OS Boot Loader Start~!!', 0 ;

DISKERRORMESSAGE:		db 'DISK Error~!!', 0
IMAGELOADINGMESSAGE: 	db 'OS Image Loading...',0
LOADINGCOMPLETEMESSAGE: db 'Complete~!!', 0

; 디스크 읽기에 관련된 변수들
SECTORNUMBER:			db 0x02
HEADNUMBER:				db 0x00
TRACKNUMBER:			db 0x00

times 510 - ($ -$$) db 0x00 		; $ 현재 라인 주소
									; $$ 현재 섹션(.TEXT)의 시작주소
									; $-$$ 현재 섹션을 기준으로 하는 오프셋

db 0x55
db 0xAA 							; magic number 0x55AA 부트로더임을 표시
