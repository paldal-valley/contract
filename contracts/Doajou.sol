pragma solidity ^0.4.24;

import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./DoaToken.sol";

contract Doajou is Ownable, DoaToken {
    using SafeMath for uint256;

    constructor(address _manager, string _name, string _symbol, uint8 _decimals)
        DoaToken(_name, _symbol, _decimals)
        Ownable() public
    {
        manager = _manager;
    }

    struct QuestionInfo {
        address questioner;
        address selectedAnswerer;
        uint256 guarantee;
    }

    /* question maps */
    mapping (uint32 => QuestionInfo) public questionMap;
    mapping (address => bool) public isWelcomeTokenGiven;

    address public manager;
    uint256 internal refundRevenue;

    /**
     * @dev Error messages for require statements
     */

    string internal constant INVALID_TOKEN_VALUES = 'Invalid token values';
    string internal constant NOT_ENOUGH_TOKENS = 'Not enough tokens';
    string internal constant AMOUNT_ZERO = 'Amount can not be 0';

    uint256 internal constant WELCOME_TOKEN_AMOUNT = 1000 * (10 ** 18);
    uint256 internal constant MAX_QUESTION_GUARANTEE = 50000 * (10 ** 18);

    function getRefundRevenue() public view returns (uint256) {
        return refundRevenue;
    }

    /**
    * getter and setter
    */

    function getQuestionOwner(uint32 questionId) public view returns (address) {
        return questionMap[questionId].questioner;
    }

    function getQuestionGuarantee(uint32 questionId) public view returns (uint256) {
        return questionMap[questionId].guarantee;
    }

    function getSelectedAnswerer(uint32 questionId) public view returns (address) {
        return questionMap[questionId].selectedAnswerer;
    }

    /* onlyQuestioner */
    function setQuestionMaps(address questioner, uint32 questionId, uint256 guarantee) internal {
        require(getQuestionOwner(questionId) == address(0));
        require(getSelectedAnswerer(questionId) == address(0));
        require(getQuestionGuarantee(questionId) == 0);

        questionMap[questionId] = QuestionInfo(questioner, 0, guarantee);
    }

    /**
    * business logic
    */

    /* onlyOwner */
    function offerWelcomeToken(address newbie) public onlyOwner {
        require(isWelcomeTokenGiven[newbie] == false);

        super.transfer(newbie, WELCOME_TOKEN_AMOUNT);
        isWelcomeTokenGiven[newbie] = true;
    }

    /* 질문 생성 시 실행 */
    /* onlyQuestioner */
    function questionCreated(address questioner, uint32 questionId, uint256 guarantee) public {
        // questioner에게 guarantee 이상의 token이 있는지 확인
        require(balanceOf(questioner) >= guarantee);
        require(guarantee <= MAX_QUESTION_GUARANTEE);

        setQuestionMaps(questioner, questionId, guarantee);
        super.transferFrom(questioner, manager, guarantee);
    }

    /* 질문 삭제 시 실행 */
    /* onlyManager */
    function removeQuestion(uint32 questionId) public {
        require(getQuestionOwner(questionId) != 0);

        // tokenTable 참조
        address questioner = getQuestionOwner(questionId);
        uint256 guarantee = getQuestionGuarantee(questionId);

        // 환불 금액 및 환불 수수료 책정
        uint256 refundAmount = guarantee.mul(9).div(10); // 90%
        uint256 refundFee = guarantee.div(10); // 10%

        // questioner에게 guarantee의 90% 환불
        super.transfer(questioner, refundAmount);
        refundRevenue = refundRevenue.add(refundFee);

        // token table로부터 guarantee 차감
        questionMap[questionId].guarantee = 0;
    }

    /* 답변 채택 시 실행 */
    /* onlyManager */
    function answerSelected(uint32 questionId, address answerer) public {
        require(getQuestionOwner(questionId) != address(0));
        require(getSelectedAnswerer(questionId) == address(0));

        uint256 guarantee = getQuestionGuarantee(questionId);
        super.transfer(answerer, guarantee);

        questionMap[questionId].selectedAnswerer = answerer;
        questionMap[questionId].guarantee = 0;
    }

    /* manager가 refund fee로 벌어들인 token 수익을 owner에게 반환하는 함수 */
    /* onlyManager */
    function takeRefundRevenue() public {
        super.transfer(owner, refundRevenue);
        refundRevenue = 0;
    }
}
