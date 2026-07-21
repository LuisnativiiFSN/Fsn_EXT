/// <summary>
/// Codeunit Customer Management (ID 50020).
/// </summary>
codeunit 50020 "Customer Management"
{
    Description = 'Codeunit Customer Management';

    trigger OnRun()
    begin

    end;

    /// <summary>
    /// SetCustDiscGroup.
    /// </summary>
    /// <param name="Code">Code[20].</param>
    /// <param name="CustDiscGroup">Code[20].</param>
    [ServiceEnabled]
    procedure SetCustDiscGroup(Code: Code[20]; CustDiscGroup: Code[20])
    var
        customer: Record Customer;
        custDiscGrp: Record "Customer Discount Group";
    begin
        customer.Get(Code);
        if custDiscGrp.Get(CustDiscGroup) and (CustDiscGroup <> '') then begin
            customer."Customer Disc. Group" := CustDiscGroup;
            customer.Modify(true);
        end;
    end;
}