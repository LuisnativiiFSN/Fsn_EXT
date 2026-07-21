reportextension 50158 "FSN Return Order Ext" extends "Return Order"
{
   
    dataset
    {
        add(PageLoop)
        {
            column(LocationCode; "Purchase Header"."Location Code")
            {
            }
            column(LocationCodeCaption; "Purchase Header".FieldCaption("Location Code"))
            {
            }
            
            column(LocationName; GetLocationName("Purchase Header"."Location Code"))
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

        // Find store by Location Code and return Name
        LSCStore.Reset();
        LSCStore.SetRange("Location Code", LocationCode);
        if LSCStore.FindFirst() then
            NameTxt := LSCStore.Name
        else
            NameTxt := '';
        exit(NameTxt);
    end;
}
