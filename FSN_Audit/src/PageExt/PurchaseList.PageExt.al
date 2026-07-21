pageextension 50170 PurchaseListExt extends "Purchase List"
{

    layout
    {
        addafter("Pay-to Name")
        {
            field("Pay-to Vendor Search Name";Rec."Pay-to Vendor Search Name")
            {
                ApplicationArea = All;
                Caption = 'Alias';
                Editable = false;
            }
        }
    }
    trigger OnAfterGetRecord()
    var
        myInt: Integer;
        Vendor: Record Vendor;
    begin
        if rec."Pay-to Vendor Search Name" = '' then

            
        if Vendor.get(Rec."Pay-to Vendor No.") then begin
            rec."Pay-to Vendor Search Name" := Vendor."Search Name";
            rec.Modify(true);
        end;                                                                                                                                                   
    end;

    var
        SearchName: Text[100];
}
