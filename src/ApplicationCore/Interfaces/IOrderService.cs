using System.Threading.Tasks;
using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;

namespace Microsoft.eShopWeb.ApplicationCore.Interfaces;

public interface IOrderService
{
    Task<Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate.Order> CreateOrderAsync(int basketId, Address shippingAddress);
}
