page 50124 "FSN Whse Receipt by Scanner"
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    InsertAllowed = false;
    DeleteAllowed = false;
    SourceTable = "FSN Global Table Temporary";
    SourceTableTemporary = true;
    Caption = 'Escanear productos Recep. WR';

    layout
    {
        area(Content)
        {

            group(GroupName)
            {
                Caption = 'Scanner';
                //Visible = NOT InvDte;
                field(Scanner; Code20_3)
                {
                    Caption = 'Scanner';
                    ApplicationArea = All;
                    trigger OnValidate()
                    var
                        Barcodes: Record "LSC Barcodes";
                        Item: Record Item;
                        PITSWMScd2sucLine: Record PITS_WMScd2suc;
                    begin

                        if not Barcodes.Get(Code20_3) then
                            exit;

                        if not Item.Get(Barcodes."Item No.") then
                            exit;

                        PITSWMScd2sucLine.Reset();
                        if Code20_1 <> '' then
                            PITSWMScd2sucLine.SetRange(PITSWMScd2sucLine."FSN Warehouse Receipt No.", Code20_1);
                        if Text_1 <> '' then
                            PITSWMScd2sucLine.SetRange(PITSWMScd2sucLine."No.", Text_1);
                        PITSWMScd2sucLine.SetRange(PITSWMScd2sucLine."Item No.", Item."No.");
                        if PITSWMScd2sucLine.FindFirst() then begin
                            if not PITSWMScd2sucLine."Ajuste Pasado" then begin
                                if PITSWMScd2sucLine."FSN Quantity Scan" < PITSWMScd2sucLine.Quantity then begin
                                    PITSWMScd2sucLine."FSN Quantity Scan" += 1;
                                    PITSWMScd2sucLine.Modify();

                                    if PITSWMScd2sucLine."FSN Quantity Scan" = PITSWMScd2sucLine.Quantity then begin
                                        PITSWMScd2sucLine."Ajuste Pasado" := true;
                                        PITSWMScd2sucLine.Modify();
                                    end;

                                    clear(Code20_3);
                                end else begin
                                    PITSWMScd2sucLine."Ajuste Pasado" := true;
                                    PITSWMScd2sucLine.Modify();
                                    clear(Code20_3);
                                    Message(Txt0);
                                end;
                            end else begin
                                clear(Code20_3);
                                Message(ValidateItem(Item."No.", true));//28981
                            end;
                        end else begin
                            clear(Code20_3);
                            Message(ValidateItem(Item."No.", false));//28981
                        end;
                    end;

                }
            }

            group(Detail)
            {
                Visible = InvDte;
                part(Lines; "FSN PITS Whse Receipt Lines")
                {
                    Editable = false;
                    ApplicationArea = All;
                    SubPageLink = "FSN Warehouse Receipt No." = FIELD(FILTER(Code20_1));
                }
            }

            group(DetailP)
            {
                Visible = InvDtePed;
                part(LinesPedido; "FSN PITS Whse Receipt Lines")
                {
                    Editable = false;
                    ApplicationArea = All;
                    SubPageLink = "No." = FIELD(FILTER("Text_1"));
                }
            }
        }
    }


    trigger OnOpenPage()
    begin
        Param.Reset();
        Param.SetRange(Grupo, 'LIMPIAR');
        Param.SetRange(Codigo, 'DEV03');
        IF Param.FindFirst() AND Param.Activo then
            Lim := true;

        Rec.Reset();
        Rec.DeleteAll(true);
        Rec.Init();
        Rec.Code20_1 := GlobalReceiptNo;
        Rec.Text_1 := GlobalReceiptNoPed;
        Rec.Code20_3 := '';
        Rec.Bool_1 := InvDte;
        Rec.Insert();
    end;

    procedure SetPurchOrderNo(pReceipt: Code[20]; LocationCode: Code[10])
    begin
        GlobalReceiptNoPed := '';
        InvDtePed := false;
        GlobalReceiptNo := pReceipt;
        InvDte := true;
        Location := LocationCode;
    end;

    procedure SetPurchOrderNoPed(pReceipt: Code[35]; LocationCode: Code[10])
    begin
        GlobalReceiptNo := '';
        InvDte := false;
        GlobalReceiptNoPed := pReceipt;
        Location := LocationCode;
        InvDtePed := true;

    end;

    procedure ValidateItem(ItemNo: Code[20]; Full: Boolean): Text
    var
        PITSWMScd2suc: Record "PITS_WMScd2suc";
        TextValue: Text;
        Header: Text;
        FinalMessage: Text;
        HeaderTextDoc: Label 'DOCUMENTO ';
        HeaderTextPed: Label '. PEDIDO ';
        Espacio: Label ' . . . . . . . . . . . . . . . . ';
        Processed: Boolean;
    begin
        clear(Header);
        clear(TextValue);

        PITSWMScd2suc.Reset();
        PITSWMScd2suc.SetRange(PITSWMScd2suc."Item No.", ItemNo);
        PITSWMScd2suc.SetRange(PITSWMScd2suc."Transfer-to Code", Location);
        PITSWMScd2suc.SetFilter(PITSWMScd2suc."FSN Warehouse Receipt No.", '<>%1', '');
        if PITSWMScd2suc.Find('-') then begin

            if Full then
                Header += Txt0 + '\\'
            else
                Header += Txt1 + '\\';
            repeat

                Processed := false;

                if Code20_1 <> '' then
                    IF PITSWMScd2suc."FSN Warehouse Receipt No." <> Code20_1 THEN
                        Processed := true;

                if Text_1 <> '' then
                    IF PITSWMScd2suc."No." <> Text_1 THEN
                        Processed := true;

                if Processed then
                    TextValue += Format(PITSWMScd2suc."FSN Warehouse Receipt No." + Espacio + PITSWMScd2suc."No.") + '\';

            until PITSWMScd2suc.Next() = 0;
        end else begin
            if Full then
                TextValue += Txt0
            else
                TextValue += Txt1;
            exit(TextValue);

        end;

        if TextValue <> '' then
            FinalMessage := Header + Format(HeaderTextDoc + Espacio + HeaderTextPed) + '\' + TextValue
        else begin
            if Full then
                FinalMessage += Txt0
            else
                FinalMessage += Txt1;
        end;

        exit(FinalMessage);
    end;

    var
        Param: Record "FSN Parameter";
        Lim: Boolean;
        InvDte: Boolean;
        InvDtePed: Boolean;
        GlobalReceiptNo: Code[20];
        GlobalReceiptNoPed: Code[35];
        Location: Code[10];
        Txt0: Label 'Linea completada.';
        Txt1: Label 'Código no encontrado. No corresponde al documento ni al pedido registrado.';

    //780006012424
    //741000342635
    //741000342635
}