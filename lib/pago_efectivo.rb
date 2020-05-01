require 'pago_efectivo/client'

module PagoEfectivo
  CURRENCIES = {soles: {id: 1, symbol: 'S/.'}, dolares: {id: 2, symbol: '$'}}
  # 1 => bancos
  # 2 => cuenta_virtual
  PAY_METHODS = [1,2]
end
