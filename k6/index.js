import { check, group, sleep } from "k6";
import http from "k6/http";

const TARGET_API_URL_1 = "https://app-api-egzezdon2qcy4.azurewebsites.net/api/catalog-items";
const TARGET_API_URL_2 = "https://app-api-egzezdon2qcy4.azurewebsites.net/api/catalog-brands";
const TARGET_API_URL_3 = "https://app-api-egzezdon2qcy4.azurewebsites.net/api/catalog-types";

export const options = {
  stages: [
    { duration: "1m", target: 500 },
    { duration: "5m", target: 500 },
    { duration: "1m", target: 500 },
  ],
};

export default function () {
  group("API Load Test Items", function () {

    const res = http.get(TARGET_API_URL_1);

    check(res, {
        "status is 200": (r) => r.status === 200,
        "response contains expected data": (r) => r.json("catalogItems").length > 0,
      });
  });

  group("API Load Test Brands", function () {
   

    const res = http.get(TARGET_API_URL_2);

    check(res, {
        "status is 200": (r) => r.status === 200,
        "response contains expected data": (r) => r.json("catalogBrands").length > 0,
      });
  });

  group("API Load Test Types", function () {
    

    const res = http.get(TARGET_API_URL_3);

    check(res, {
        "status is 200": (r) => r.status === 200,
        "response contains expected data": (r) => r.json("catalogTypes").length > 0,
      });
  });

  sleep(1);
}