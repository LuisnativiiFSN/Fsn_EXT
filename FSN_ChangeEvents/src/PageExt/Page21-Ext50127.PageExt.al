pageextension 50128 PageExtension50128 extends "Customer Card"
{

    trigger OnOpenPage()
    var
        Parametros: Record "FSN Parameter";
        UserRec: Record User;
    begin
        Editable := true;

        if isEditableCustomer(Rec) then
            exit;

        UserRec.Get(UserSecurityId());
        Parametros.SetRange(Grupo, 'CREDCOB');
        Parametros.SetRange(Codigo, UserRec."User Name");
        if Parametros.FindFirst() then begin
            if not Parametros.Activo then begin
                Editable := false;
                Message('Su usario esta desactivado para la modificación de fichas de clientes');
            end;
        end else begin
            Editable := false;
            Message('No tiene permisos para modificar fichas de clientes');
        end;


    end;

    local procedure isEditableCustomer(Customer: Record Customer): Boolean
    var
        attribute: Record "LSC Attribute Value";
    begin
        attribute.SetRange("Attribute Code", 'CLIENTES');
        attribute.SetRange("Link Type", attribute."Link Type"::Customer);
        attribute.SetRange("Link Field 1", Customer."No.");
        attribute.SetRange("Attribute Value", 'NO EDITABLE');
        if attribute.FindSet() then
            exit(false);

        exit(true);
    end;
}


