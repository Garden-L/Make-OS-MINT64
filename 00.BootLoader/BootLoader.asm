[org 0]		; 코드의 시작 어드레스를 0으로 설정
[BITS 16]		; 이하의 코드는 16비트 코드로 설정

SECTION .TEXT 	; TEXT 세그먼트 정의

MOV ax, 0xB800
MOV ds, ax 	; DS 세그먼트 레지스터에 비디오 제어 주소를 복사

MOV byte[0x00], 'M'	; DS : PC(IP) = 0xB8000:0, 세그먼트 주소는 0x4만큼 곱해준다.
MOV byte[0x01], '0x4A'	; 빨간배경 밝은 녹색

JMP $

TIMES 510 - ($ -$$) DB 0x00 ; $ 현재 라인 주소
			; $$ 현재 섹션(.TEXT)의 시작주소
			; $-$$ 현재 섹션을 기준으로 하는 오프셋

DB 0x55
DB 0xAA ; magic number 0x55AA 부트로더임을 표시
