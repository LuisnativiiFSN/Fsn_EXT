reportextension 50159 "FSN Return Shipment Ext" extends "Return Shipment"
{
    
    dataset
    {
        add(PageLoop)
        {
            column(LocationCode; "Return Shipment Header"."Location Code")
            {
            }
            column(LocationCodeCaption; "Return Shipment Header".FieldCaption("Location Code"))
            {
            }
            column(LocationName; GetLocationName("Return Shipment Header"."Location Code"))
            {
            }
        }
    }

    var
        LSCStore: Record "LSC Store";

    local procedure GetLocationName(LocationCode: Code[10]): Text[100]
    var
        NameTxt: Text[100];
    begin
        if LocationCode = '' then
            exit('');

        LSCStore.Reset();
        LSCStore.SetRange("Location Code", LocationCode);
        if LSCStore.FindFirst() then
            NameTxt := LSCStore.Name
        else
            NameTxt := '';
        exit(NameTxt);
    end;
}
