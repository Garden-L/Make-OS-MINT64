[org 0]		; 코드의 시작 어드레스를 0으로 설정
[BITS 16]		; 이하의 코드는 16비트 코드로 설정

SECTION .TEXT 	; TEXT 세그먼트 정의

jmp 0x07C0:START 	; CS=0x07C0, IP(PC)=0x5(START의 인덱스)

START:				; 0x5
	mov ax, 0x07C0
	mov ds, ax		;ds 레지스터를 파일이 로드되어있는 메모리 첫 주소
	mov ax, 0xB800	;비디오 메모리 시작 주소
	mov es, ax		;es=0xB800
	
	mov si, 0		;SI=0 원본 인덱스 레지스터

.SCREENCLEARLOOP:	;clear monitor
	mov byte [es:si], 0 	; 비디오 메모리의 0을 넣을 경우 클리어됨
	mov byte [es:si + 1], 0x0A 		;바탕색=밝은녹색

	add si, 2		; 2byte 인덱스

	cmp si, 80 * 25 * 2	;화면전체크기= 80*25, 문자인식 = 1, 색조정=1
						;si 와 일치하지 않으면 Zero register = 1
	jl .SCREENCLEARLOOP ; 

	mov si, 0		;si 레지스터 초기화
	mov di, 0		;di 레지스터 초기화

.MESSAGELOOP:		;메세지 출력 함수
	mov cl, byte [MESSAGE1 + si]	;CX레지스터 하위 8비트에 
									;MESSAGE1에 SI OFFSET

	cmp cl, 0
	je .MESSAGEEND

	mov byte [es:di], cl

	add si, 1
	add di, 2

	jmp .MESSAGELOOP

.MESSAGEEND:
	jmp $

MESSAGE1:	db 'MINT64 OS Boot Loader Start~!!', 0 ;

times 510 - ($ -$$) db 0x00 ; $ 현재 라인 주소
			; $$ 현재 섹션(.TEXT)의 시작주소
			; $-$$ 현재 섹션을 기준으로 하는 오프셋

db 0x55
db 0xAA ; magic number 0x55AA 부트로더임을 표시
