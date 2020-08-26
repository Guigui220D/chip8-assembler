LD V1 0x00
LD V2 0x00
LD V3 0x20
LD I 0x000

:Loop
    DRW V1 V2 0x5
    LD DT V3
    LD ST V3
:Label1
    LD V4 DT
    SE V4 0x00
    JP :Label1
    DRW V1 V2 0x5
    LD DT V3
:Label2
    LD V4 DT
    SE V4 0x00
    JP :Label2
    JP :Loop