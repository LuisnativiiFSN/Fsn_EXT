codeunit 50043 "FSN Purchase SOAP Service"
{
    Subtype = Normal;

    procedure ReceiveText20(InputText: Text[20]): Text var PurchaseHeader: Record "Purchase Header";
    ReleasePurchDoc: Codeunit "Release Purchase Document";
    UpdatedCount: Integer;
    ReleasedCount: Integer;
    begin
        if InputText = '' then Error('InputText no puede estar vacio.');
        PurchaseHeader.Reset();
        PurchaseHeader.SetRange("Document Type", PurchaseHeader."Document Type"::Order);
        PurchaseHeader.SetRange("LSC General Comments", InputText);
        if PurchaseHeader.FindSet(true)then repeat PurchaseHeader."FSN Consolidate No.":=InputText;
                PurchaseHeader.Modify(true);
                UpdatedCount+=1;
                if PurchaseHeader.Status = PurchaseHeader.Status::Open then begin
                    ReleasePurchDoc.PerformManualRelease(PurchaseHeader);
                    ReleasedCount+=1;
                end;
            until PurchaseHeader.Next() = 0;
        if UpdatedCount > 0 then exit(StrSubstNo('OK|ReceivedText=%1|Updated=%2|Released=%3', InputText, UpdatedCount, ReleasedCount));
        exit(StrSubstNo('FAILD|ReceivedText=%1|Updated=%2|Released=%3', InputText, UpdatedCount, ReleasedCount));
    end;
}
