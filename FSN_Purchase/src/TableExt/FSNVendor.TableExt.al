tableextension 50121 "FSN Vendor" extends Vendor
{
    fields
    {
        field(60010; "Associated Credit Memo"; Boolean)
        {
            Caption = 'Associated Credit Memo';
            DataClassification = ToBeClassified;
            //Activar 
            trigger OnValidate()
            var
                Text001: Label '¿Desea Activar la solicitud de Nota de Credito Asociada en los Pedidos de Reaprovisionamiento?';
                Text002: Label '¿Desea Desactivar la solicitud de Nota de Credito Asociada en los Pedidos de Reaprovisionamiento?';
                ExtPurch: Codeunit "FSN External Purch. Manager";
            begin
                if "Associated Credit Memo" then
                    if Confirm(Text001, false) then
                        ExtPurch.UpdateReplenAssocCreditMemo('UPDASSOCRP', Rec."No.", true);
                if not "Associated Credit Memo" then
                    if Confirm(Text002, false) then
                        ExtPurch.UpdateReplenAssocCreditMemo('UPDASSOCRP', Rec."No.", false);

            end;
        }
        field(60011; "DTE Issue"; Boolean)
        {
            Caption = 'DTE Issue';
            DataClassification = ToBeClassified;
        }

    }
}